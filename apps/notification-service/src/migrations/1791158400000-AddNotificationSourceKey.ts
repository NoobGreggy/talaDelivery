import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddNotificationSourceKey1791158400000 implements MigrationInterface {
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE notifications ADD COLUMN IF NOT EXISTS source_key varchar(120) NULL`);
    await queryRunner.query(`CREATE UNIQUE INDEX IF NOT EXISTS notifications_source_key_unique ON notifications (source_key)`);
  }
  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX notifications_source_key_unique`);
    await queryRunner.query(`ALTER TABLE notifications DROP COLUMN source_key`);
  }
}
