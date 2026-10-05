import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddOpeningHoursToStores1727637200000 implements MigrationInterface {
  name = 'AddOpeningHoursToStores1727637200000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "stores"
      ADD COLUMN "opening_hours" jsonb
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "stores"
      DROP COLUMN "opening_hours"
    `);
  }
}
