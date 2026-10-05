import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

/**
 * Refresh-token family row (token names/`jti` from the JWTs). Only a SHA-256
 * hash of the refresh token is stored; rotation deletes the old family and
 * records the new one. `user_id` references identity users (no cross-DB FK).
 */
@Entity('refresh_tokens')
export class RefreshToken {
  @PrimaryGeneratedColumn()
  id: number;

  @Index()
  @Column({ name: 'user_id', type: 'int' })
  userId: number;

  /** `jti` shared by the access + refresh token of the same family. */
  @Index({ unique: true })
  @Column({ type: 'varchar', length: 64 })
  jti: string;

  /** SHA-256 of the raw refresh token. */
  @Column({ name: 'token_hash', type: 'varchar', length: 64 })
  tokenHash: string;

  @Column({ name: 'expires_at', type: 'timestamptz' })
  expiresAt: Date;

  @Column({ name: 'revoked_at', type: 'timestamptz', nullable: true })
  revokedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}