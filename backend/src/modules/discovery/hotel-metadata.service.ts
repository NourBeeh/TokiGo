import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Hotel } from '../../database/entities/hotel.entity';

/** Provider-agnostic metadata shape used by the sync pipeline. */
export interface ProviderHotelMetadata {
  providerHotelId: string;
  name?: string;
  nameLocal?: string;
  city?: string;
  countryCode?: string;
  address?: string;
  description?: string;
  descriptionLocal?: string;
  facilities?: string[];
  category?: string;
  latitude?: number;
  longitude?: number;
  /** Deterministic object key of an already-optimized image, when known. */
  imageObjectKey?: string;
}

const COUNTRY_NAMES: Record<string, string> = {
  egypt: 'EG',
  'united arab emirates': 'AE',
  uae: 'AE',
  'saudi arabia': 'SA',
  turkey: 'TR',
  'united kingdom': 'GB',
  france: 'FR',
  italy: 'IT',
  spain: 'ES',
  germany: 'DE',
  greece: 'GR',
  qatar: 'QA',
  kuwait: 'KW',
  jordan: 'JO',
  'united states': 'US',
  canada: 'CA',
  thailand: 'TH',
  singapore: 'SG',
  malaysia: 'MY',
  japan: 'JP',
};

function countryCodeOf(value: unknown): string {
  const raw = String(value ?? '').trim();
  if (/^[A-Za-z]{2}$/.test(raw)) return raw.toUpperCase();
  return COUNTRY_NAMES[raw.toLowerCase()] ?? '';
}

function stringList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => {
      if (typeof item === 'string') return item.trim();
      if (item && typeof item === 'object') {
        const label = (item as any).name ?? (item as any).label ?? (item as any).title;
        return typeof label === 'string' ? label.trim() : '';
      }
      return '';
    })
    .filter(Boolean);
}

/**
 * Map a Nuitee/Duffel hotel metadata object into the provider-agnostic shape.
 * Returns null when there is no stable provider hotel id — such a record must
 * never enter the source of truth.
 */
export function mapProviderHotel(
  raw: any,
  providerId: string,
  fallbackCity?: string,
  fallbackCountry?: string,
): (ProviderHotelMetadata & { providerId: string }) | null {
  if (!raw || typeof raw !== 'object') return null;
  const providerHotelId = String(raw.id ?? raw.hotelId ?? '').trim();
  if (!providerHotelId) return null;

  const name =
    (typeof raw.name === 'string' && raw.name.trim()) ||
    (typeof raw.nameEn === 'string' && raw.nameEn.trim()) ||
    `Hotel ${providerHotelId}`;
  const rawName = typeof raw.name === 'string' ? raw.name : name;
  const nameLocal =
    (typeof raw.nameAr === 'string' && raw.nameAr.trim()) ||
    (containsArabicScript(rawName) ? rawName : undefined);

  const address =
    raw?.address?.addressLine1 ??
    raw?.address?.address ??
    raw?.address_line_1 ??
    undefined;

  return {
    providerId,
    providerHotelId,
    name,
    nameLocal,
    city:
      raw?.city_name ??
      raw?.address?.cityName ??
      raw?.city ??
      fallbackCity ??
      '',
    countryCode: countryCodeOf(
      raw?.country_code ??
        raw?.countryName ??
        raw?.address?.countryName ??
        raw?.country,
    ) || (fallbackCountry ?? ''),
    address: typeof address === 'string' ? address : undefined,
    description: typeof raw.description === 'string' ? raw.description : undefined,
    descriptionLocal:
      typeof raw.descriptionAr === 'string' ? raw.descriptionAr : undefined,
    facilities: stringList(raw.facilities ?? raw.amenities),
    category:
      raw.stars !== undefined && raw.stars !== null
        ? String(raw.stars)
        : typeof raw.type === 'string'
          ? raw.type
          : undefined,
    latitude: typeof raw.latitude === 'number' ? raw.latitude : undefined,
    longitude: typeof raw.longitude === 'number' ? raw.longitude : undefined,
  };
}

function containsArabicScript(value: string): boolean {
  return /[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]/.test(value);
}

export interface HotelDiscoveryQuery {
  query?: string;
  city?: string;
  countryCode?: string;
  facilities?: string[];
  limit: number;
  offset: number;
}

export interface HotelDiscoveryPage {
  hits: Hotel[];
  total: number;
}

/**
 * PostgreSQL hotel metadata source of truth and Meilisearch fallback.
 *
 * Holds NO price columns; discovery queries only metadata.
 */
@Injectable()
export class HotelMetadataService {
  constructor(
    @InjectRepository(Hotel)
    private readonly hotels: Repository<Hotel>,
  ) {}

  /**
   * Idempotent upsert by (providerId, providerHotelId). Re-running the same
   * provider payload updates in place and refreshes `lastSyncedAt`.
   */
  async upsert(metadata: ProviderHotelMetadata & { providerId: string }): Promise<Hotel> {
    const existing = await this.hotels.findOne({
      where: {
        providerId: metadata.providerId,
        providerHotelId: metadata.providerHotelId,
      },
    });

    const values: Partial<Hotel> = {
      name: metadata.name ?? existing?.name ?? `Hotel ${metadata.providerHotelId}`,
      nameLocal: metadata.nameLocal ?? null,
      city: metadata.city ?? existing?.city ?? '',
      countryCode: metadata.countryCode ?? existing?.countryCode ?? '',
      address: metadata.address ?? null,
      description: metadata.description ?? null,
      descriptionLocal: metadata.descriptionLocal ?? null,
      facilities: metadata.facilities ?? [],
      category: metadata.category ?? null,
      latitude: metadata.latitude ?? null,
      longitude: metadata.longitude ?? null,
      imageObjectKey: metadata.imageObjectKey ?? existing?.imageObjectKey ?? null,
      isActive: true,
      isDeleted: false,
      lastSyncedAt: new Date(),
    };

    if (existing) {
      await this.hotels.update({ id: existing.id }, values);
      return { ...existing, ...values } as Hotel;
    }
    return this.hotels.save(this.hotels.create(values));
  }

  /** Soft removal — the row stays for audit and can be re-activated by sync. */
  async markRemoved(providerId: string, providerHotelId: string): Promise<boolean> {
    const result = await this.hotels.update(
      { providerId, providerHotelId },
      { isDeleted: true, isActive: false },
    );
    return Boolean(result.affected);
  }

  async findByProviderId(
    providerId: string,
    providerHotelId: string,
  ): Promise<Hotel | null> {
    return this.hotels.findOne({ where: { providerId, providerHotelId } });
  }

  /**
   * PostgreSQL fallback discovery: full-text OR prefix matching over the
   * metadata columns, exact city/country filters, JSONB facility containment.
   */
  async search(query: HotelDiscoveryQuery): Promise<HotelDiscoveryPage> {
    const qb = this.hotels
      .createQueryBuilder('hotel')
      .where('hotel."isDeleted" = false')
      .andWhere('hotel."isActive" = true');

    const term = query.query?.trim();
    if (term) {
      qb.andWhere(
        `(
          to_tsvector('simple',
            coalesce(hotel.name, '') || ' ' ||
            coalesce(hotel."nameLocal", '') || ' ' ||
            coalesce(hotel.city, '') || ' ' ||
            coalesce(hotel."countryCode", '') || ' ' ||
            coalesce(hotel.address, '') || ' ' ||
            coalesce(hotel.description, '')
          ) @@ plainto_tsquery('simple', :term)
          OR hotel.name ILIKE :like
          OR hotel.city ILIKE :like
        )`,
        { term, like: `%${term}%` },
      );
    }

    if (query.city) {
      qb.andWhere('hotel.city = :city', { city: query.city });
    }
    if (query.countryCode) {
      qb.andWhere('hotel."countryCode" = :countryCode', {
        countryCode: query.countryCode.toUpperCase(),
      });
    }
    for (const facility of query.facilities ?? []) {
      qb.andWhere(`hotel.facilities @> :facility::jsonb`, {
        facility: JSON.stringify([facility]),
      });
    }

    const [hits, total] = await Promise.all([
      qb
        .orderBy('hotel.name', 'ASC')
        .skip(query.offset)
        .take(query.limit)
        .getMany(),
      qb.getCount(),
    ]);

    return { hits, total };
  }
}
