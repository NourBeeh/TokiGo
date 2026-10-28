import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from 'typeorm';

/**
 * One behavioural signal collected for the recommendation engine (R-3).
 *
 * Each row is a lightweight fact: what the user did, with which payload, when.
 * Keys either a registered userId or an anonymous deviceId (guest flows) —
 * exactly one is set. No free-text, no personal data beyond ids.
 */
@Entity('user_events')
export class UserEvent {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ nullable: true })
  userId?: string;

  @Column({ nullable: true })
  deviceId?: string;

  @Column()
  type!: string; // hotel_search | hotel_view | favorite | trip_planned | ...

  @Column({ type: 'jsonb', default: () => "'{}'::jsonb" })
  payload!: Record<string, any>;

  @CreateDateColumn()
  createdAt!: Date;
}
