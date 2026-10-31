import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddShareRatio1792000000001 implements MigrationInterface {
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE dispatch_settings ADD COLUMN IF NOT EXISTS share_ratio varchar(16) NOT NULL DEFAULT '70/30'`);
  }

  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE dispatch_settings DROP COLUMN IF EXISTS share_ratio`);
  }
}