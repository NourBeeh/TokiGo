import { Entity, PrimaryColumn, CreateDateColumn } from 'typeorm';

@Entity('processed_webhooks')
export class ProcessedWebhook {
  @PrimaryColumn({ type: 'varchar', length: 255 })
  id!: string;

  @CreateDateColumn()
  processedAt!: Date;
}