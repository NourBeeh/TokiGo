import { Injectable, Logger } from '@nestjs/common';
import { Hotel } from '../../database/entities/hotel.entity';
import { NuiteeService } from '../nuitee/nuitee.service';
import { HotelMetadataService, mapProviderHotel } from './hotel-metadata.service';
import {
  HotelSearchDocument,
  MeilisearchHotelIndexService,
} from './meilisearch-hotel-index.service';

/** Normalised discovery hit returned by the API (never a price). */
export interface HotelDiscoveryHit {
  id: string;
  providerId: string;
  providerHotelId: string;
  name: string;
  nameLocal?: string | null;
  city: string;
  countryCode: string;
  address?: string | null;
  description?: string | null;
  facilities: string[];
  category?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  imageObjectKey?: string | null;
}

export interface DiscoveryResult {
  source: 'meilisearch' | 'postgres';
  hits: HotelDiscoveryHit[];
  total: number;
  limit: number;
  offset: number;
  hasMore: boolean;
}

export function toDiscoveryHit(hotel: Hotel): HotelDiscoveryHit {
  return {
    id: hotel.id,
    providerId: hotel.providerId,
    providerHotelId: hotel.providerHotelId,
    name: hotel.name,
    nameLocal: hotel.nameLocal ?? null,
    city: hotel.city,
    countryCode: hotel.countryCode,
    address: hotel.address ?? null,
    description: hotel.description ?? null,
    facilities: Array.isArray(hotel.facilities) ? hotel.facilities : [],
    category: hotel.category ?? null,
    latitude: hotel.latitude ?? null,
    longitude: hotel.longitude ?? null,
    imageObjectKey: hotel.imageObjectKey ?? null,
  };
}

function fromDocument(doc: HotelSearchDocument): HotelDiscoveryHit {
  return {
    id: doc.id,
    providerId: doc.providerId,
    providerHotelId: doc.providerHotelId,
    name: doc.name,
    nameLocal: doc.nameLocal ?? null,
    city: doc.city,
    countryCode: doc.countryCode,
    address: doc.address ?? null,
    description: doc.description ?? null,
    facilities: Array.isArray(doc.facilities) ? doc.facilities : [],
    category: doc.category ?? null,
    latitude: doc.latitude ?? null,
    longitude: doc.longitude ?? null,
    imageObjectKey: doc.imageObjectKey ?? null,
  };
}

/**
 * Hotel discovery orchestration (high-load refactor).
 *
 * Meilisearch answers metadata search when healthy; any failure falls back to
 * PostgreSQL transparently and reports which source served the response.
 * Live prices are never part of this path — discovery returns hotel ids that
 * the client then prices through the live search endpoint.
 */
@Injectable()
export class HotelDiscoveryService {
  private readonly logger = new Logger(HotelDiscoveryService.name);

  constructor(
    private readonly metadata: HotelMetadataService,
    private readonly index: MeilisearchHotelIndexService,
    private readonly nuitee: NuiteeService,
  ) {}

  async discover(query: {
    query?: string;
    city?: string;
    countryCode?: string;
    facilities?: string[];
    limit: number;
    offset: number;
  }): Promise<DiscoveryResult> {
    const meili = await this.index.search(query);
    if (meili) {
      return {
        source: 'meilisearch',
        hits: meili.hits.map(fromDocument),
        total: meili.total,
        limit: query.limit,
        offset: query.offset,
        hasMore: query.offset + query.limit < meili.total,
      };
    }

    const page = await this.metadata.search(query);
    return {
      source: 'postgres',
      hits: page.hits.map(toDiscoveryHit),
      total: page.total,
      limit: query.limit,
      offset: query.offset,
      hasMore: query.offset + query.limit < page.total,
    };
  }

  /**
   * Synchronize one city's metadata from the provider into PostgreSQL (source
   * of truth) and then Meilisearch. Idempotent: re-running replaces the same
   * rows and documents.
   */
  async syncCity(input: {
    city: string;
    country?: string;
    language?: string;
  }): Promise<{ synced: number; indexed: number }> {
    const result = await this.nuitee.hotelContent(
      input.city,
      input.country,
      input.language,
    );
    if (!result.success || !Array.isArray(result.data)) {
      throw new Error(`provider sync failed: ${result.error ?? 'unknown'}`);
    }

    const saved: Hotel[] = [];
    for (const raw of result.data as any[]) {
      const mapped = mapProviderHotel(raw, 'nuitee', input.city, input.country);
      if (!mapped) continue;
      saved.push(await this.metadata.upsert(mapped));
    }

    let indexed = 0;
    if (this.index.enabled) {
      try {
        await this.index.indexHotels(saved);
        indexed = saved.length;
      } catch (error) {
        // Metadata stays correct in PostgreSQL; the index retry can re-run.
        this.logger.error(
          `Meilisearch indexing failed for ${input.city}: ${
            (error as Error).message
          }`,
        );
      }
    }

    return { synced: saved.length, indexed };
  }
}
