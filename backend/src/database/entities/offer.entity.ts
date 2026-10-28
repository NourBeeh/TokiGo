import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('offers')
export class Offer {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  providerId!: string;

  @Column()
  type!: string;

  @Column({ type: 'jsonb' })
  data!: Record<string, any>;

  @Column({ type: 'jsonb', nullable: true })
  price?: Record<string, any>;

  @Column({ default: true })
  isVisible!: boolean;

  @Column({ nullable: true })
  validUntil?: Date;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
