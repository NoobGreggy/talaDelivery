import { MigrationInterface, QueryRunner } from 'typeorm';
export class MerchantProfileFields1791170000000 implements MigrationInterface {
  async up(runner: QueryRunner): Promise<void> {
    await runner.query('ALTER TABLE stores ADD COLUMN IF NOT EXISTS description text NULL, ADD COLUMN IF NOT EXISTS email varchar(254) NULL');
  }
  async down(runner: QueryRunner): Promise<void> {
    await runner.query('ALTER TABLE stores DROP COLUMN email, DROP COLUMN description');
  }
}
