import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

/**
 * Aggregated user profile for the recommendation engine (workstream R).
 *
 * Combines explicit preferences (set by the user or updated implicitly) with
 * derived behavioural signals. Stored as JSON so the schema can grow without
 * migrations. Optional for guests: rows exist only for registered users
 * (userId) — guest behaviour lives in the user_events table keyed by deviceId,
 * and the recommendation engine works from events alone for them.
 */
@Entity('user_profiles')
export class UserProfile {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ unique: true })
  userId!: string;

  /** Explicit preferences: price range, star rating, amenities, destinations. */
  @Column({ type: 'jsonb', default: () => "'{}'::jsonb" })
  preferences!: Record<string, any>;

  /** Derived behavioural profile: top destinations, price band, seasons, etc. */
  @Column({ type: 'jsonb', default: () => "'{}'::jsonb" })
  derived!: Record<string, any>;

  /** Last country detected (ISO-2) with confidence. */
  @Column({ nullable: true })
  countryCode?: string;

  @Column({ nullable: true })
  countryConfidence?: string;

  /** Opt-out for personalised recommendations (privacy). */
  @Column({ default: false })
  personalizationEnabled!: boolean;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
