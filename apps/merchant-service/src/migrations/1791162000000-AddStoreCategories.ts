import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddStoreCategories1791162000000 implements MigrationInterface {
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE TABLE IF NOT EXISTS store_categories (
      id SERIAL PRIMARY KEY, name varchar(80) NOT NULL, normalized_name varchar(80) NOT NULL UNIQUE,
      description varchar(500) NULL, is_active boolean NOT NULL DEFAULT true,
      created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
    )`);
    await queryRunner.query(`CREATE TABLE IF NOT EXISTS store_category_tags (
      store_id integer NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
      category_id integer NOT NULL REFERENCES store_categories(id) ON DELETE CASCADE,
      PRIMARY KEY (store_id, category_id)
    )`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS store_category_tags_category_idx ON store_category_tags (category_id)`);
  }
  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE store_category_tags`);
    await queryRunner.query(`DROP TABLE store_categories`);
  }
}
