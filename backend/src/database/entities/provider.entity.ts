import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn } from 'typeorm';

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
