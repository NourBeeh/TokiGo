import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn } from 'typeorm';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ unique: true })
  email!: string;

  @Column({ nullable: true })
  displayName?: string;

  @Column({ nullable: true })
  title?: string;

  @Column({ nullable: true })
  firstName?: string;

  @Column({ nullable: true })
  middleName?: string;

  @Column({ nullable: true })
  lastName?: string;

  @Column({ type: 'date', nullable: true })
  dateOfBirth?: Date;

  @Column({ nullable: true })
  gender?: string;

  @Column({ nullable: true })
  nationality?: string;

  @Column({ nullable: true })
  avatarUrl?: string;

  @Column({ nullable: true })
  phoneNumber?: string;

  @Column({ type: 'text', nullable: true, select: false })
  passwordHash?: string | null;

  /// Google account id (`sub`) once the user has linked Google sign-in.
  /// Nullable: password-only accounts, and several NULLs are legal in a unique
  /// index on Postgres.
  @Column({ type: 'varchar', length: 64, nullable: true, unique: true })
  googleId?: string | null;

  @Column({ default: false })
  isActive!: boolean;

  @Column({ default: 'user' })
  role!: string;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}