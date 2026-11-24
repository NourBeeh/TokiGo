import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Hotel } from '../../database/entities/hotel.entity';
import { boundingBox, GeoPoint, isValidCoordinate } from './geo';

/** A hotel row as the nearby pipeline needs it (metadata + position only). */
export interface NearbyHotelRecord {
  id: string;
  providerHotelId: string;
  name: string;
  city: string;
  countryCode: string;
  imageObjectKey: string | null;
  imageUrl: string | null;
  latitude: number;
  longitude: number;
  rating: number | null;
  reviewCount: number | null;
  distanceKm: number;
}

interface RawHotelRow {
  id: string;
  providerHotelId: string;
  name: string;
  city: string;
  countryCode: string;
  imageObjectKey: string | null;
  imageUrl: string | null;
  latitude: string | number;
  longitude: string | number;
  rating: string | number | null;
  reviewCount: string | number | null;
  distanceKm: string | number;
}

/**
 * PostgreSQL geographic store for Nearby Stays (R1).
 *
 * PostGIS is deliberately NOT required: the radius filter is a pure-SQL
 * haversine over the existing double-precision `latitude`/`longitude`
 * columns, with a latitude/longitude bounding box as a selective prefilter.
 * That runs on the stock `postgres:16` image the project already provisions;
 * no extension, no new infrastructure.
 *
 * Only metadata is read. No price, rate or availability column is consulted.
 */
@Injectable()
export class NearbyHotelRepository {
  constructor(
    @InjectRepository(Hotel)
    private readonly hotels: Repository<Hotel>,
  ) {}

  /**
   * Hotels within [radiusKm] of [center], nearest first.
   *
   * Hotels without valid coordinates are excluded — they can never be placed
   * honestly, and a city-centre substitute would be a fabricated position.
   */
  async findWithinRadius(
    center: GeoPoint,
    radiusKm: number,
    limit: number,
  ): Promise<NearbyHotelRecord[]> {
    if (!isValidCoordinate(center.latitude, center.longitude) || !(radiusKm > 0)) {
      return [];
    }
    const safeLimit = Math.min(Math.max(1, Math.floor(limit)), 200);
    const box = boundingBox(center, radiusKm);
    const wrapsAntimeridian = box.minLng < -180 || box.maxLng > 180;

    const distanceSql = `(6371 * acos(LEAST(1, GREATEST(-1,
      cos(radians($1)) * cos(radians(latitude)) *
      cos(radians(longitude) - radians($2)) +
      sin(radians($1)) * sin(radians(latitude))
    ))))`;

    const longitudePredicate = wrapsAntimeridian
      ? 'AND longitude IS NOT NULL'
      : 'AND longitude BETWEEN $5 AND $6';

    const sql = `
      SELECT
        id,
        "providerHotelId",
        name,
        city,
        "countryCode",
        "imageObjectKey",
        "imageUrl",
        latitude,
        longitude,
        rating,
        "reviewCount",
        ${distanceSql} AS "distanceKm"
      FROM hotels
      WHERE "isDeleted" = false
        AND "isActive" = true
        AND latitude IS NOT NULL
        AND longitude IS NOT NULL
        AND latitude BETWEEN $3 AND $4
        ${longitudePredicate}
        AND ${distanceSql} <= $7
      ORDER BY "distanceKm" ASC
      LIMIT $8
    `;

    const rows = (await this.hotels.query(sql, [
      center.latitude,
      center.longitude,
      box.minLat,
      box.maxLat,
      box.minLng,
      box.maxLng,
      radiusKm,
      safeLimit,
    ])) as RawHotelRow[];

    return rows.map((row) => this.toRecord(row));
  }

  private toRecord(row: RawHotelRow): NearbyHotelRecord {
    const latitude = Number(row.latitude);
    const longitude = Number(row.longitude);
    return {
      id: String(row.id),
      providerHotelId: String(row.providerHotelId),
      name: String(row.name),
      city: String(row.city ?? ''),
      countryCode: String(row.countryCode ?? ''),
      imageObjectKey: row.imageObjectKey ?? null,
      imageUrl: row.imageUrl ?? null,
      latitude,
      longitude,
      rating: row.rating === null ? null : Number(row.rating),
      reviewCount: row.reviewCount === null ? null : Number(row.reviewCount),
      distanceKm: Number(row.distanceKm),
    };
  }
}
