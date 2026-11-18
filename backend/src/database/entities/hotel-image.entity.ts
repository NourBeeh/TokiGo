import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

/**
 * Optimized hotel image record (high-load refactor, Phase 2).
 *
 * Only the CDN URL and encoding metadata are persisted. Image binaries live in
 * S3/R2; the provider's original URL is never stored as the permanent URL (a
 * hash of it is kept for duplicate detection only). `objectKey` is
 * deterministic and unique, so re-processing the same image can never create a
 * second object.
 */
@Entity('hotel_images')
@Index('uq_hotel_images_object_key', ['objectKey'], { unique: true })
@Index('idx_hotel_images_hotel', ['hotelId'], {
  where: `"hotelId" IS NOT NULL`,
})
export class HotelImage {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  /** Nullable: an image may be fetched before its hotel metadata row exists. */
  @Column({ type: 'uuid', nullable: true })
  hotelId?: string | null;

  @Column({ type: 'varchar', length: 512 })
  objectKey!: string;

  @Column({ type: 'varchar', length: 1024 })
  cdnUrl!: string;

  /** SHA-256 of the provider source URL — dedupe/audit, not a fetchable URL. */
  @Column({ type: 'varchar', length: 64, nullable: true })
  sourceUrlHash?: string | null;

  @Column({ type: 'int', nullable: true })
  width?: number | null;

  @Column({ type: 'int', nullable: true })
  height?: number | null;

  @Column({ type: 'varchar', default: 'image/webp' })
  contentType!: string;

  @Column({ type: 'int', nullable: true })
  bytes?: number | null;

  /** Immutable edge policy: versioned keys make a one-year TTL safe. */
  @Column({ type: 'varchar', default: 'public, max-age=31536000, immutable' })
  cacheControl!: string;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
