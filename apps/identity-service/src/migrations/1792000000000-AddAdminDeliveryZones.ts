import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddAdminDeliveryZones1792000000000 implements MigrationInterface {
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS delivery_zone_ids integer[] NOT NULL DEFAULT '{}'`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE users DROP COLUMN IF EXISTS delivery_zone_ids`);
  }
}