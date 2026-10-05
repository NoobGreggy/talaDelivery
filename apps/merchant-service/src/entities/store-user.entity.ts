import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn, Unique } from 'typeorm';

/** Membership projection: user_id belongs to identity-service, so no foreign key. */
@Entity('store_users')
@Unique(['storeId', 'userId'])
@Index(['userId'])
export class StoreUser {
  @PrimaryGeneratedColumn() id: number;
  @Column({ name: 'store_id', type: 'int' }) storeId: number;
  @Column({ name: 'user_id', type: 'int' }) userId: number;
  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' }) createdAt: Date;
}
