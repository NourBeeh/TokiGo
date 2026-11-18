import { Injectable, Logger } from '@nestjs/common';
import {
  GetObjectCommand,
  HeadObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';

/**
 * S3-compatible object storage (AWS S3 or Cloudflare R2).
 *
 * Objects are addressed by deterministic, content-derived keys so an upload is
 * idempotent: re-processing the same photo produces the same key and simply
 * overwrites an identical object. The CDN domain is configurable; nothing
 * here stores binary data in PostgreSQL.
 */
@Injectable()
export class ObjectStorageService {
  private readonly logger = new Logger(ObjectStorageService.name);
  private readonly client: S3Client;
  private readonly bucket: string;

  constructor() {
    this.bucket = process.env.S3_BUCKET ?? '';
    const endpoint = process.env.S3_ENDPOINT?.trim();
    this.client = new S3Client({
      region: process.env.S3_REGION || 'auto',
      endpoint: endpoint || undefined,
      // R2/minio-style endpoints require path-style addressing.
      forcePathStyle: Boolean(endpoint) || process.env.S3_FORCE_PATH_STYLE === 'true',
      credentials: {
        accessKeyId: process.env.S3_ACCESS_KEY_ID ?? '',
        secretAccessKey: process.env.S3_SECRET_ACCESS_KEY ?? '',
      },
    });
  }

  get configured(): boolean {
    return Boolean(this.bucket && process.env.S3_ACCESS_KEY_ID);
  }

  /** Public CDN origin that fronts the bucket. */
  cdnBaseUrl(): string {
    return (
      process.env.CDN_BASE_URL?.trim().replace(/\/+$/, '') ||
      process.env.S3_PUBLIC_BASE_URL?.trim().replace(/\/+$/, '') ||
      ''
    );
  }

  cdnUrlFor(objectKey: string): string {
    const base = this.cdnBaseUrl();
    return base ? `${base}/${objectKey}` : `s3://${this.bucket}/${objectKey}`;
  }

  /** True when the object already exists — lets callers skip an upload. */
  async exists(objectKey: string): Promise<boolean> {
    if (!this.configured) return false;
    try {
      await this.client.send(
        new HeadObjectCommand({ Bucket: this.bucket, Key: objectKey }),
      );
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Upload with an immutable edge policy. Content-addressed keys make the
   * one-year TTL safe: an updated image gets a different key.
   */
  async putObject(input: {
    key: string;
    body: Buffer;
    contentType: string;
    cacheControl?: string;
  }): Promise<void> {
    if (!this.configured) {
      throw new Error('S3/R2 is not configured (S3_BUCKET/S3_ACCESS_KEY_ID missing).');
    }
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: input.key,
        Body: input.body,
        ContentType: input.contentType,
        CacheControl:
          input.cacheControl ?? 'public, max-age=31536000, immutable',
      }),
    );
  }

  /** Signed/unsigned fetch of an object (used by tests and diagnostics). */
  async getObjectBuffer(key: string): Promise<Buffer | null> {
    if (!this.configured) return null;
    try {
      const result = await this.client.send(
        new GetObjectCommand({ Bucket: this.bucket, Key: key }),
      );
      const bytes = await result.Body!.transformToByteArray();
      return Buffer.from(bytes);
    } catch (error) {
      this.logger.warn(`Object fetch failed for ${key}: ${(error as Error).message}`);
      return null;
    }
  }
}
