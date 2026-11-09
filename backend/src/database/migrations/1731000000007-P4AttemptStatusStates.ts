import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * P4-2 migration 7 — replace the `payment_attempts` status CHECK.
 *
 * P4-1 shipped an ad-hoc status list (`created`, `requires_confirmation`,
 * `pending`, `succeeded`, `failed`, `unknown`, `consumed`, `voided`,
 * `refunded`, `partially_refunded`). P4-2 introduces an explicit state machine
 * (see `src/modules/payments/payment-attempt.state.ts`) that additionally
 * distinguishes:
 *
 *   processing        — a gateway call is in flight
 *   requires_action   — REQUIRES_CONFIRMATION (renamed from
 *                       `requires_confirmation`; same meaning, one canonical
 *                       name so the model and the database cannot drift)
 *   declined          — the customer's method was refused
 *   cancelled         — a real cancellation operation completed
 *
 * `requires_confirmation` is mapped to `requires_action` before the new
 * constraint is applied, so no existing row is lost or rewritten to a value it
 * never held.
 *
 * The new set is intentionally a superset of the old one (plus the rename), so
 * this is a widening change: no previously legal value becomes illegal except
 * the renamed one, which is translated.
 *
 * Reversible: `down()` translates `requires_action` back to
 * `requires_confirmation` and restores the P4-1 constraint.
 */
export class P4AttemptStatusStates1731000000007 implements MigrationInterface {
  name = 'P4AttemptStatusStates1731000000007';

  private static readonly OLD_CONSTRAINT = 'chk_payment_attempts_status';
  private static readonly NEW_SET = [
    'created',
    'processing',
    'requires_action',
    'pending',
    'succeeded',
    'declined',
    'failed',
    'unknown',
    'cancelled',
    'consumed',
    'voided',
    'refunded',
    'partially_refunded',
  ];
  private static readonly OLD_SET = [
    'created',
    'requires_confirmation',
    'pending',
    'succeeded',
    'failed',
    'unknown',
    'consumed',
    'voided',
    'refunded',
    'partially_refunded',
  ];

  public async up(queryRunner: QueryRunner): Promise<void> {
    // Drop the P4-1 constraint FIRST: the translation below writes
    // `requires_action`, which the old constraint would reject.
    await queryRunner.query(`
      ALTER TABLE payment_attempts
      DROP CONSTRAINT IF EXISTS chk_payment_attempts_status
    `);
    // Translate the one renamed value before applying the new constraint.
    await queryRunner.query(`
      UPDATE payment_attempts
      SET status = 'requires_action'
      WHERE status = 'requires_confirmation'
    `);
    await queryRunner.query(`
      ALTER TABLE payment_attempts
      ADD CONSTRAINT chk_payment_attempts_status CHECK (
        status IN (${P4AttemptStatusStates1731000000007.NEW_SET.map(s => `'${s}'`).join(', ')})
      )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE payment_attempts
      DROP CONSTRAINT IF EXISTS chk_payment_attempts_status
    `);
    // Translate back, then restore the P4-1 constraint.
    await queryRunner.query(`
      UPDATE payment_attempts
      SET status = 'requires_confirmation'
      WHERE status = 'requires_action'
    `);

    await queryRunner.query(`
      ALTER TABLE payment_attempts
      ADD CONSTRAINT chk_payment_attempts_status CHECK (
        status IN (${P4AttemptStatusStates1731000000007.OLD_SET.map(s => `'${s}'`).join(', ')})
      )
    `);
  }
}
