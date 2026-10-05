import { MigrationInterface, QueryRunner } from 'typeorm';
export class CustomerOrderNotes1791175000000 implements MigrationInterface {
  async up(runner: QueryRunner): Promise<void> { await runner.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS notes text NULL'); }
  async down(runner: QueryRunner): Promise<void> { await runner.query('ALTER TABLE orders DROP COLUMN notes'); }
}
