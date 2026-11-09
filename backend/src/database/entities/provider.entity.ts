import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';

/**
 * Provider registry row (ADM-B1).
 *
 * P4-1 flight mutual exclusion is enforced by a partial unique index on
 * `providers(vertical)` (active + flight + `duffel-flight`/`nuitee-flight`).
 * That index is intentionally declared ONLY in migration
 * `1731000000006-P4FlightProviderSelection`, not on this entity.
 *
 * Why: `synchronize` (development) creates every index declared on an entity.
 * Development also runs `RegistrySyncService.seedDefaults`, which seeds more
 * than one active flight provider, so an entity-level unique index would break
 * development initialization. Production never synchronizes — it runs the
 * migration chain with `synchronize: false`, and the migration is the single
 * authoritative enforcement point. Declaring the index here would therefore
 * only create a dev/prod divergence and a dev boot regression, with no
 * production benefit.
 */
@Entity('providers')
export class Provider {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  /** Stable key == the provider instance `providerId` (e.g. 'nuitee'). */
  @Column({ unique: true })
  providerKey!: string;

  @Column()
  name!: string;

  @Column({ type: 'jsonb', nullable: true })
  config?: Record<string, any>;

  @Column({ default: true })
  isActive!: boolean;

  /** Search vertical this provider serves: flight | hotel | car. */
  @Column({ type: 'varchar', nullable: true })
  vertical?: string;

  /** Lower runs first within the vertical (1 = primary). */
  @Column({ type: 'int', default: 0 })
  priority!: number;

  /** Marks documented fallback providers (admin UI hint). */
  @Column({ default: false })
  isFallback!: boolean;

  /** Last health probe outcome: healthy | unhealthy | unknown. */
  @Column({ type: 'varchar', nullable: true, default: 'unknown' })
  healthStatus?: string;

  @Column({ type: 'int', nullable: true })
  latencyMs?: number;

  @Column({ type: 'timestamptz', nullable: true })
  lastCheckedAt?: Date;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
