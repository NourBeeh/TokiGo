import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

/**
 * Hotel metadata record (high-load refactor, Phase 2).
 *
 * Metadata ONLY. There is deliberately no price, rate, availability or
 * check-in/check-out column: hotel prices are live provider data and must
 * never be persisted here. Check-in/out dates are search parameters, not
 * hotel attributes.
 *
 * This table is the source for Meilisearch synchronization AND the safe
 * PostgreSQL fallback when Meilisearch is unavailable. Meilisearch is never
 * the source of truth — this row is.
 */
@Entity('hotels')
@Index('uq_hotels_provider_hotel', ['providerId', 'providerHotelId'], {
  unique: true,
})
@Index('idx_hotels_city_country', ['city', 'countryCode'], {
  where: `"isDeleted" = false`,
})
@Index('idx_hotels_active_city', ['isActive', 'city'], {
  where: `"isDeleted" = false`,
})
@Index('idx_hotels_last_synced', ['lastSyncedAt'], {
  where: `"isDeleted" = false`,
})
export class Hotel {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  /** Stable provider key, e.g. 'nuitee'. */
  @Column({ type: 'varchar' })
  providerId!: string;

  /** Provider's own hotel id. */
  @Column({ type: 'varchar' })
  providerHotelId!: string;

  @Column({ type: 'varchar' })
  name!: string;

  /** Localised (Arabic) name when the provider supplies one. */
  @Column({ type: 'varchar', nullable: true })
  nameLocal?: string | null;

  @Column({ type: 'varchar' })
  city!: string;

  @Column({ type: 'varchar', length: 2 })
  countryCode!: string;

  @Column({ type: 'text', nullable: true })
  address?: string | null;

  @Column({ type: 'text', nullable: true })
  description?: string | null;

  @Column({ type: 'text', nullable: true })
  descriptionLocal?: string | null;

  /** Facility names as a JSONB string array. */
  @Column({ type: 'jsonb', default: () => "'[]'" })
  facilities!: string[];

  /** Star/category label, e.g. '5' or 'resort'. */
  @Column({ type: 'varchar', nullable: true })
  category?: string | null;

  @Column({ type: 'double precision', nullable: true })
  latitude?: number | null;

  @Column({ type: 'double precision', nullable: true })
  longitude?: number | null;

  /** Deterministic object key of the optimized CDN image (no binary data). */
  @Column({ type: 'varchar', nullable: true })
  imageObjectKey?: string | null;

  @Column({ default: true })
  isActive!: boolean;

  /** Soft removal: Meilisearch removals must not delete the source of truth. */
  @Column({ default: false })
  isDeleted!: boolean;

  @Column({ type: 'timestamptz', nullable: true })
  lastSyncedAt?: Date | null;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
