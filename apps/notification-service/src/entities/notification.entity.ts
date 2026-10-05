import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

@Entity('notifications')
@Index(['userId'])
export class Notification {
  @Index({ unique: true })
  @Column({ name: 'source_key', type: 'varchar', length: 120, nullable: true }) sourceKey: string | null;
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'user_id', type: 'int' }) userId: number;
  @Column({ type: 'varchar', length: 50 }) type: string;
  @Column({ type: 'varchar', length: 200 }) title: string;
  @Column({ type: 'text' }) body: string;
  @Column({ type: 'jsonb', nullable: true }) data: Record<string, unknown> | null;
  @Column({ name: 'is_read', type: 'boolean', default: false }) isRead: boolean;
  @Column({ name: 'read_at', type: 'timestamptz', nullable: true }) readAt: Date | null;
  @Column({ name: 'sent_at', type: 'timestamptz', nullable: true }) sentAt: Date | null;
  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' }) createdAt: Date;
}
