import { MigrationInterface, QueryRunner } from 'typeorm';

export class StoreCategoryIcons1791176000000 implements MigrationInterface {
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE store_categories ADD COLUMN IF NOT EXISTS icon varchar(60) NOT NULL DEFAULT 'restaurant_rounded'`);
    await queryRunner.query(`UPDATE store_categories SET icon = CASE
      WHEN normalized_name LIKE '%grocery%' OR normalized_name LIKE '%market%' THEN 'local_grocery_store_rounded'
      WHEN normalized_name LIKE '%pharm%' OR normalized_name LIKE '%health%' THEN 'medication_rounded'
      WHEN normalized_name LIKE '%parcel%' OR normalized_name LIKE '%delivery%' THEN 'inventory_2_rounded'
      WHEN normalized_name LIKE '%deal%' OR normalized_name LIKE '%promo%' THEN 'local_offer_rounded'
      ELSE icon END WHERE icon = 'restaurant_rounded'`);
  }
  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('ALTER TABLE store_categories DROP COLUMN icon');
  }
}
