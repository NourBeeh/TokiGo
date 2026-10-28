import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('home_sections')
export class HomeSection {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  title!: string;

  @Column({ nullable: true })
  subtitle?: string;

  @Column()
  layout!: string;

  @Column({ type: 'int' })
  order!: number;

  @Column({ default: true })
  isVisible!: boolean;

  @Column({ nullable: true })
  expiresAt?: Date;

  /** Publication time: the public feed hides the section until then. */
  @Column({ type: 'timestamptz', nullable: true })
  publishAt?: Date;

  /** Content lifecycle: drafts never reach the public home feed. */
  @Column({ default: 'published' })
  status!: string;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
