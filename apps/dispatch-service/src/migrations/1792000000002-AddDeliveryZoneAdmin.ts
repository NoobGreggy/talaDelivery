import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddDeliveryZoneAdmin1792000000002 implements MigrationInterface {
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE delivery_zones ADD COLUMN IF NOT EXISTS admin_id integer NULL`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE delivery_zones DROP COLUMN IF EXISTS admin_id`);
  }
}
