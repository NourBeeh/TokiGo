import { Entity, PrimaryColumn, CreateDateColumn } from 'typeorm';

/**
 * Legacy webhook replay record (pre-P4-2).
 *
 * RETIRED AS A WRITER, RETAINED AS AN ARCHIVE + COMPATIBILITY CHECK.
 *
 * P4-2 originally dropped this table (migration 8). That destroyed historical
 * deduplication records, so P4-2R restores it: the table is kept, its rows are
 * preserved, and `PaymentService.handleWebhook` checks it before processing.
 * A webhook id that was processed before P4-2 must never be applied again.
 *
 * Identity semantics are the ORIGINAL ones and are deliberately NOT modernised:
 * the key is the bare event id, with no provider column. The only gateway that
 * has ever emitted webhooks into this table is the Egyptian gateway, so the
 * original meaning is preserved exactly rather than inventing a provider value
 * the historical rows never had.
 *
 * New events are recorded in BOTH tables (the legacy insert is
 * `ON CONFLICT DO NOTHING`) so the two stores cannot drift apart. `webhook_events`
 * remains the authoritative store for events first seen after P4-2.
 */
@Entity('processed_webhooks')
export class ProcessedWebhook {
  @PrimaryColumn({ type: 'varchar', length: 255 })
  id!: string;

  @CreateDateColumn()
  processedAt!: Date;
}
