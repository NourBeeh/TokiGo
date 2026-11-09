import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryColumn,
  UpdateDateColumn,
} from 'typeorm';

/**
 * Singleton active-flight-provider selection (P4-1).
 *
 * The `providers.isActive` flag can only enforce "at most one active flight
 * provider" (a partial unique index). It cannot enforce "exactly one is
 * selected", and it would make a zero-provider state indistinguishable from a
 * healthy one. This table is the explicit selection record:
 *
 *   - `selectionKey` is the primary key with a CHECK pinning it to 'flight',
 *     so the table can hold AT MOST one row (a singleton).
 *   - ZERO rows means "no flight provider selected" — an explicit, queryable
 *     state. The system must report `provider_unavailable` rather than
 *     silently falling back to a provider.
 *   - ONE row names the selected provider.
 *
 * A partial unique index on `providers` (active, real flight) is the hard
 * backstop that stops two real flight providers being active at once, and
 * database triggers (migration 6) make every selection row self-validating:
 * the selected provider must be active, a flight provider, and one of the two
 * real flight providers. A selected provider's `providerKey`, `vertical` and
 * `isActive` cannot be changed by a direct UPDATE while it is selected.
 *
 * This is schema only in P4-1: no runtime read/write is wired yet (P4-6 owns
 * the admin switch). The migration inserts the row only when the pre-existing
 * data already has exactly one active candidate — it never promotes a fallback.
 */
@Entity('provider_selection')
export class ProviderSelection {
  /** Singleton key — always 'flight' (CHECKed in the migration). */
  @PrimaryColumn({ type: 'varchar' })
  selectionKey!: string;

  /** The selected provider's stable key (FK to providers.providerKey). */
  @Column({ type: 'varchar' })
  providerKey!: string;

  @Column({ type: 'timestamptz', default: () => 'now()' })
  selectedAt!: Date;

  /** Admin user who made the selection (audit). */
  @Column({ type: 'varchar', nullable: true })
  selectedBy?: string | null;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
