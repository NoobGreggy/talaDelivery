import { MigrationInterface, QueryRunner } from 'typeorm';
export class StoreDeliveryZones1791246000000 implements MigrationInterface {
  async up(runner: QueryRunner): Promise<void> {
    await runner.query("ALTER TABLE stores ADD COLUMN IF NOT EXISTS delivery_zone_ids integer[] NOT NULL DEFAULT '{}'");
  }
  async down(runner: QueryRunner): Promise<void> {
    await runner.query('ALTER TABLE stores DROP COLUMN delivery_zone_ids');
  }
}
