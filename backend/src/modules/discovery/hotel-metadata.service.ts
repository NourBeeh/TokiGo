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
  /** Guest review average on the 5-point display scale; null when absent. */
  rating?: number;
  /** Provider-reported review count; null when absent. */
  reviewCount?: number;
  /** Deterministic object key of an already-optimized image, when known. */
  imageObjectKey?: string;
  /** Provider's own photo URL, when it sent one. */
  imageUrl?: string;
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
      if (typeof item === 'number') return String(item);
      if (item && typeof item === 'object') {
        const label = (item as any).name ?? (item as any).label ?? (item as any).title;
        return typeof label === 'string' ? label.trim() : '';
      }
      return '';
    })
    .filter(Boolean);
}

/** Accepts a real number or a numeric string; anything else is absent. */
function finiteNumber(value: unknown): number | undefined {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string' && value.trim()) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return undefined;
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

  // Only a name the provider actually sent. The honest `Hotel <id>` fallback
  // belongs to INSERT time (see `upsert`); fabricating it here made a sparse
  // payload look complete and overwrote a real stored name on re-sync.
  const name =
    (typeof raw.name === 'string' && raw.name.trim()) ||
    (typeof raw.nameEn === 'string' && raw.nameEn.trim()) ||
    undefined;
  const rawName = name ?? '';
  const nameLocal =
    (typeof raw.nameAr === 'string' && raw.nameAr.trim()) ||
    (rawName.length > 0 && containsArabicScript(rawName) ? rawName : undefined);

  const address =
    raw?.address?.addressLine1 ??
    raw?.address?.address ??
    raw?.address_line_1 ??
    (typeof raw?.address === 'string' ? raw.address : undefined);

  // The provider quotes a 10-point guest score; the app displays a 5-point
  // scale. Convert here, once, so the catalog and the live offer mapper can
  // never disagree. A score outside 0–10 is treated as absent rather than
  // clamped into a plausible-looking number.
  const rawRating = finiteNumber(raw.rating);
  const rating =
    rawRating !== undefined && rawRating >= 0 && rawRating <= 10
      ? Math.round(Math.min(5, Math.max(0, rawRating / 2)) * 100) / 100
      : undefined;

  // `/data/hotels` uses `reviewCount`; the rates metadata uses
  // `review_count`. Both are accepted, nothing is invented.
  const rawReviewCount = finiteNumber(raw.reviewCount ?? raw.review_count);
  const reviewCount =
    rawReviewCount !== undefined && rawReviewCount >= 0
      ? Math.round(rawReviewCount)
      : undefined;

  const latitude = finiteNumber(raw.latitude ?? raw.address?.latitude);
  const longitude = finiteNumber(raw.longitude ?? raw.address?.longitude);

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
    description:
      typeof raw.hotelDescription === 'string'
        ? raw.hotelDescription
        : typeof raw.description === 'string'
          ? raw.description
          : undefined,
    descriptionLocal:
      typeof raw.descriptionAr === 'string' ? raw.descriptionAr : undefined,
    facilities: stringList(
      raw.facilities ??
        raw.amenities ??
        raw.facilityIds ??
        raw.hotelFacilities,
    ),
    category:
      raw.stars !== undefined && raw.stars !== null
        ? String(raw.stars)
        : typeof raw.type === 'string'
          ? raw.type
          : undefined,
    latitude: latitude !== undefined && latitude >= -90 && latitude <= 90 ? latitude : undefined,
    longitude:
      longitude !== undefined && longitude >= -180 && longitude <= 180
        ? longitude
        : undefined,
    rating,
    reviewCount,
    imageUrl:
      (typeof raw.main_photo === 'string' && raw.main_photo.trim()) ||
      (typeof raw.thumbnail === 'string' && raw.thumbnail.trim()) ||
      undefined,
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
   *
   * A sparse provider payload NEVER erases previously valid data: every
   * optional field falls back to the existing row. This is what keeps a
   * partial sync from wiping coordinates, ratings or descriptions.
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
      nameLocal: metadata.nameLocal ?? existing?.nameLocal ?? null,
      city: metadata.city || existing?.city || '',
      countryCode: metadata.countryCode || existing?.countryCode || '',
      address: metadata.address ?? existing?.address ?? null,
      description: metadata.description ?? existing?.description ?? null,
      descriptionLocal: metadata.descriptionLocal ?? existing?.descriptionLocal ?? null,
      facilities:
        metadata.facilities && metadata.facilities.length > 0
          ? metadata.facilities
          : (existing?.facilities ?? []),
      category: metadata.category ?? existing?.category ?? null,
      latitude: metadata.latitude ?? existing?.latitude ?? null,
      longitude: metadata.longitude ?? existing?.longitude ?? null,
      rating: metadata.rating ?? existing?.rating ?? null,
      reviewCount: metadata.reviewCount ?? existing?.reviewCount ?? null,
      imageObjectKey: metadata.imageObjectKey ?? existing?.imageObjectKey ?? null,
      imageUrl: metadata.imageUrl ?? existing?.imageUrl ?? null,
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
