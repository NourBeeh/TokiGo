import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Hotel } from '../../database/entities/hotel.entity';

/** Metadata-only document indexed in Meilisearch. NO price/availability. */
export interface HotelSearchDocument {
  id: string;
  providerId: string;
  providerHotelId: string;
  name: string;
  nameLocal?: string;
  city: string;
  countryCode: string;
  address?: string;
  description?: string;
  facilities: string[];
  category?: string;
  latitude?: number;
  longitude?: number;
  imageObjectKey?: string;
  isActive: boolean;
  isDeleted: boolean;
}

/**
 * Meilisearch hotel index (high-load refactor).
 *
 * Discovery/metadata search ONLY. Prices, availability and room rates are
 * never indexed. The PostgreSQL `hotels` table remains the source of truth;
 * this service degrades to "disabled" (callers fall back) whenever Meilisearch
 * is unreachable instead of failing the request.
 * The SDK is ESM-only, so it is loaded lazily through a native dynamic import
  * (kept out of TypeScript's CommonJS transform) and only when a host is
  * configured — tests and deployments without Meilisearch never load it.
  */
 @Injectable()
 export class MeilisearchHotelIndexService {
   private readonly logger = new Logger(MeilisearchHotelIndexService.name);
   private readonly indexUid: string;
   private readonly host: string;
   private readonly apiKey: string;
   private clientPromise: Promise<any | null> | null = null;
   private indexReady = false;

   constructor(config: ConfigService) {
     this.indexUid = config.get<string>('meilisearch.index') ?? 'hotels';
     this.host = config.get<string>('meilisearch.host') ?? '';
     this.apiKey = config.get<string>('meilisearch.apiKey') ?? '';
     if (!this.host.trim()) {
       this.logger.log('MEILISEARCH_HOST unset — discovery falls back to PostgreSQL.');
     }
   }

   get enabled(): boolean {
     return Boolean(this.host.trim());
   }

   /** Load (once) and return the SDK client, or null when unavailable. */
   private async getClient(): Promise<any | null> {
     if (!this.enabled) return null;
     if (!this.clientPromise) {
       this.clientPromise = (async () => {
         try {
           const importer = new Function(
             'specifier',
             'return import(specifier)',
           ) as (specifier: string) => Promise<any>;
           const mod = await importer('meilisearch');
           const Ctor = mod.Meilisearch ?? mod.default?.Meilisearch;
           if (!Ctor) throw new Error('meilisearch export missing');
           return new Ctor({
             host: this.host.trim(),
             apiKey: this.apiKey.trim() || undefined,
           });
         } catch (error) {
           this.logger.warn(
             `Meilisearch client unavailable, PostgreSQL fallback active: ${
               (error as Error).message
             }`,
           );
           return null;
         }
       })();
     }
     return this.clientPromise;
   }

  /** Cheap health probe used by /health and by the fallback decision. */
  async healthy(): Promise<boolean> {
    const client = await this.getClient();
    if (!client) return false;
    try {
      return Boolean(await client.isHealthy());
    } catch {
      return false;
    }
  }

  /** Create the index and apply settings; safe to call repeatedly. */
  async ensureIndex(client: any): Promise<void> {
    if (!client || this.indexReady) return;
    try {
      const task = await client.createIndex(this.indexUid, { primaryKey: 'id' });
      await client.tasks.waitForTask(task.taskUid ?? task);
      await client.index(this.indexUid).updateSettings({
        searchableAttributes: [
          'name',
          'nameLocal',
          'city',
          'countryCode',
          'address',
          'description',
          'facilities',
          'category',
        ],
        filterableAttributes: [
          'city',
          'countryCode',
          'category',
          'facilities',
          'isActive',
          'isDeleted',
        ],
        sortableAttributes: ['name'],
      });
      this.indexReady = true;
    } catch (error) {
      // Index may already exist with these settings — treat as ready.
      this.logger.warn(
        `Meilisearch index setup failed (fallback stays available): ${
          (error as Error).message
        }`,
      );
      this.indexReady = true;
    }
  }

  /** Upsert one metadata row; idempotent by primary key. */
  async indexHotel(hotel: Hotel): Promise<void> {
    const client = await this.getClient();
    if (!client) return;
    await this.ensureIndex(client);
    const task = await client.index(this.indexUid).addDocuments([toDocument(hotel)]);
    await client.tasks.waitForTask(task.taskUid ?? task);
  }

  /** Bulk upsert inside a synchronization job. */
  async indexHotels(hotels: Hotel[]): Promise<void> {
    if (hotels.length === 0) return;
    const client = await this.getClient();
    if (!client) return;
    await this.ensureIndex(client);
    const task = await client
      .index(this.indexUid)
      .addDocuments(hotels.map(toDocument));
    await client.tasks.waitForTask(task.taskUid ?? task);
  }

  async removeHotel(id: string): Promise<void> {
    const client = await this.getClient();
    if (!client) return;
    try {
      const task = await client.index(this.indexUid).deleteDocument(id);
      await client.tasks.waitForTask(task.taskUid ?? task);
    } catch (error) {
      this.logger.warn(`Meilisearch removal failed for ${id}: ${(error as Error).message}`);
    }
  }

  /**
   * Metadata search. Returns null when Meilisearch is unavailable so the caller
   * can answer from PostgreSQL.
   */
  async search(params: {
    query?: string;
    city?: string;
    countryCode?: string;
    facilities?: string[];
    limit: number;
    offset: number;
  }): Promise<{ hits: HotelSearchDocument[]; total: number } | null> {
    const client = await this.getClient();
    if (!client) return null;
    try {
      await this.ensureIndex(client);
      const filters = ['isDeleted = false', 'isActive = true'];
      if (params.city) filters.push(`city = ${escapeFilter(params.city)}`);
      if (params.countryCode)
        filters.push(`countryCode = ${escapeFilter(params.countryCode)}`);
      for (const facility of params.facilities ?? []) {
        filters.push(`facilities = ${escapeFilter(facility)}`);
      }

      const response = await client.index(this.indexUid).search(params.query ?? '', {
        filter: filters.join(' AND '),
        limit: params.limit,
        offset: params.offset,
      });

      return {
        hits: (response.hits as HotelSearchDocument[]) ?? [],
        total: (response.estimatedTotalHits ?? response.totalHits ?? 0) as number,
      };
    } catch (error) {
      this.logger.warn(
        `Meilisearch search failed, PostgreSQL fallback will serve: ${
          (error as Error).message
        }`,
      );
      return null;
    }
  }
}

function toDocument(hotel: Hotel): HotelSearchDocument {
  return {
    id: hotel.id,
    providerId: hotel.providerId,
    providerHotelId: hotel.providerHotelId,
    name: hotel.name,
    nameLocal: hotel.nameLocal ?? undefined,
    city: hotel.city,
    countryCode: hotel.countryCode,
    address: hotel.address ?? undefined,
    description: hotel.description ?? undefined,
    facilities: Array.isArray(hotel.facilities) ? hotel.facilities : [],
    category: hotel.category ?? undefined,
    latitude: hotel.latitude ?? undefined,
    longitude: hotel.longitude ?? undefined,
    imageObjectKey: hotel.imageObjectKey ?? undefined,
    isActive: hotel.isActive,
    isDeleted: hotel.isDeleted,
  };
}

/** Meilisearch filter values must be quoted strings. */
function escapeFilter(value: string): string {
  return `"${String(value).replace(/"/g, '')}"`;
}
