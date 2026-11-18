import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { createHash } from 'crypto';
import { Repository } from 'typeorm';
import sharp, { Metadata } from 'sharp';
import { HotelImage } from '../../database/entities/hotel-image.entity';
import { ObjectStorageService } from '../../common/storage/object-storage.service';
import { fetchAuthorizedImage } from '../../common/images/image-fetch.util';

/** Immutable edge policy for content-addressed object keys. */
export const IMAGE_CACHE_CONTROL = 'public, max-age=31536000, immutable';

const MIN_DIMENSION = 80;
const MAX_DIMENSION = 8_000;
const MAX_OUTPUT_BYTES = 2 * 1024 * 1024;
const UPLOAD_ATTEMPTS = 3;

export interface OptimizedImageResult {
  id: string;
  hotelId: string | null;
  objectKey: string;
  cdnUrl: string;
  width: number | null;
  height: number | null;
  contentType: string;
  bytes: number | null;
  cacheControl: string;
  reused: boolean;
}

/**
 * Dedicated hotel image pipeline (high-load refactor).
 *
 *   provider URL → validate (HTTPS/public/host, type, size) → WebP transcode
 *   → deterministic object key → S3/R2 → PostgreSQL metadata row (CDN URL)
 *
 * The original provider URL is never stored as the permanent image URL; only
 * its SHA-256 hash is kept for duplicate detection. Binary data never enters
 * PostgreSQL, and a repeated request returns the existing row without
 * downloading the photo again.
 */
@Injectable()
export class ImageService {
  private readonly logger = new Logger(ImageService.name);

  constructor(
    private readonly storage: ObjectStorageService,
    @InjectRepository(HotelImage)
    private readonly images: Repository<HotelImage>,
  ) {}

  /** Existing optimized image for this provider URL, if any. */
  async findRunning(sourceUrl: string): Promise<HotelImage | null> {
    const hash = sha256(sourceUrl);
    return this.images.findOne({ where: { sourceUrlHash: hash } });
  }

  async findById(id: string): Promise<HotelImage | null> {
    return this.images.findOne({ where: { id } });
  }

  /**
   * Full pipeline. Idempotent on both the source URL (sourceUrlHash) and the
   * encoded object (objectKey unique): re-running can never create a second
   * object or a second metadata row.
   */
  async optimizeAndUpload(input: {
    sourceUrl: string;
    hotelId?: string | null;
    width?: number;
  }): Promise<OptimizedImageResult> {
    // 1. Duplicate guard BEFORE downloading: never fetch the same URL twice.
    const existing = await this.findRunning(input.sourceUrl);
    if (existing) {
      return { ...this.toResult(existing), reused: true };
    }

    // 2. Authorized fetch with SSRF/redirect protection and type+size checks.
    const fetched = await fetchAuthorizedImage(input.sourceUrl);
    if (!fetched) {
      throw new Error('Image source is not an authorized, fetchable image.');
    }

    // 3. Validate dimensions and transcode to WebP.
    const encoded = await this.transcode(fetched.bytes, input.width ?? undefined);

    // 4. Content-addressed, deterministic object key.
    const sourceHash = sha256(input.sourceUrl);
    const outputHash = sha256(encoded.bytes);
    const widthLabel = encoded.width ?? 'original';
    const objectKey = `hotels/${sourceHash.slice(0, 16)}/${widthLabel}x/${outputHash}.webp`;

    // 5. Upload (skip when the exact object already exists).
    let reusedObject = false;
    if (await this.storage.exists(objectKey)) {
      reusedObject = true;
    } else {
      await this.putWithRetry(objectKey, encoded.bytes, encoded.contentType);
    }

    // 6. Persist only the CDN URL + encoding metadata.
    const saved = await this.persist({
      hotelId: input.hotelId ?? null,
      objectKey,
      cdnUrl: this.storage.cdnUrlFor(objectKey),
      sourceUrlHash: sourceHash,
      width: encoded.width,
      height: encoded.height,
      contentType: encoded.contentType,
      bytes: encoded.bytes.length,
    });

    return { ...this.toResult(saved), reused: reusedObject };
  }

  /** Transcode + dimension validation. Throws on an unsafe/unsupported image. */
  async transcode(
    bytes: Buffer,
    targetWidth?: number,
  ): Promise<{ bytes: Buffer; contentType: string; width?: number; height?: number }> {
    let metadata: Metadata;
    try {
      metadata = await sharp(bytes, { failOn: 'none' }).metadata();
    } catch (error) {
      throw new Error(`Unsupported or corrupt image: ${(error as Error).message}`);
    }

    const width = metadata.width ?? 0;
    const height = metadata.height ?? 0;
    if (
      width < MIN_DIMENSION ||
      height < MIN_DIMENSION ||
      width > MAX_DIMENSION ||
      height > MAX_DIMENSION
    ) {
      throw new Error(
        `Image dimensions ${width}x${height} are outside the allowed range.`,
      );
    }
    if (metadata.format && !['jpeg', 'png', 'webp', 'gif', 'avif', 'tiff'].includes(metadata.format)) {
      throw new Error(`Unsupported image format: ${metadata.format}`);
    }

    const pipeline = sharp(bytes, { failOn: 'none' })
      .rotate()
      .resize({
        width: targetWidth ? Math.min(targetWidth, MAX_DIMENSION) : undefined,
        withoutEnlargement: true,
      });
    const output = await pipeline
      .webp({ quality: 80, effort: 4 })
      .toBuffer({ resolveWithObject: true });

    if (output.data.length === 0 || output.data.length > MAX_OUTPUT_BYTES) {
      throw new Error('Encoded image exceeds the maximum output size.');
    }

    return {
      bytes: output.data,
      contentType: 'image/webp',
      width: output.info.width,
      height: output.info.height,
    };
  }

  private async putWithRetry(
    objectKey: string,
    body: Buffer,
    contentType: string,
  ): Promise<void> {
    let lastError: unknown;
    for (let attempt = 1; attempt <= UPLOAD_ATTEMPTS; attempt += 1) {
      try {
        await this.storage.putObject({
          key: objectKey,
          body,
          contentType,
          cacheControl: IMAGE_CACHE_CONTROL,
        });
        return;
      } catch (error) {
        lastError = error;
        if (attempt < UPLOAD_ATTEMPTS) {
          await new Promise((resolve) => setTimeout(resolve, 250 * attempt));
        }
      }
    }
    throw new Error(
      `Object upload failed after ${UPLOAD_ATTEMPTS} attempts: ${
        (lastError as Error).message
      }`,
    );
  }

  /** INSERT ... ON CONFLICT (objectKey) DO NOTHING, then read the row back. */
  private async persist(values: {
    hotelId: string | null;
    objectKey: string;
    cdnUrl: string;
    sourceUrlHash: string;
    width?: number;
    height?: number;
    contentType: string;
    bytes: number;
  }): Promise<HotelImage> {
    await this.images
      .createQueryBuilder()
      .insert()
      .into(HotelImage)
      .values({
        hotelId: values.hotelId ?? null,
        objectKey: values.objectKey,
        cdnUrl: values.cdnUrl,
        sourceUrlHash: values.sourceUrlHash,
        width: values.width ?? null,
        height: values.height ?? null,
        contentType: values.contentType,
        bytes: values.bytes,
        cacheControl: IMAGE_CACHE_CONTROL,
      })
      .orIgnore()
      .execute();

    const row = await this.images.findOne({
      where: { objectKey: values.objectKey },
    });
    if (!row) {
      throw new Error(`Image row was not persisted for ${values.objectKey}.`);
    }
    return row;
  }

  private toResult(row: HotelImage): OptimizedImageResult {
    return {
      id: row.id,
      hotelId: row.hotelId ?? null,
      objectKey: row.objectKey,
      cdnUrl: row.cdnUrl,
      width: row.width ?? null,
      height: row.height ?? null,
      contentType: row.contentType,
      bytes: row.bytes ?? null,
      cacheControl: row.cacheControl || IMAGE_CACHE_CONTROL,
      reused: false,
    };
  }
}

function sha256(value: string | Buffer): string {
  return createHash('sha256').update(value).digest('hex');
}
