import { MigrationInterface, QueryRunner } from 'typeorm';
export class MerchantProductFields1791170000000 implements MigrationInterface {
  async up(runner: QueryRunner): Promise<void> {
    await runner.query('ALTER TABLE products ADD COLUMN IF NOT EXISTS sku varchar(120) NULL, ADD COLUMN IF NOT EXISTS image text NULL');
  }
  async down(runner: QueryRunner): Promise<void> {
    await runner.query('ALTER TABLE products DROP COLUMN image, DROP COLUMN sku');
  }
}
