import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateCatalogTables1727637300000 implements MigrationInterface {
  name = 'CreateCatalogTables1727637300000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "categories" (
        "id" SERIAL PRIMARY KEY,
        "store_id" integer NOT NULL,
        "name" character varying(160) NOT NULL,
        "description" text,
        "sort_order" integer NOT NULL DEFAULT 0,
        "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_categories_store_id" ON "categories" ("store_id")
    `);
    await queryRunner.query(`
      CREATE TABLE "products" (
        "id" SERIAL PRIMARY KEY,
        "store_id" integer NOT NULL,
        "category_id" integer,
        "name" character varying(200) NOT NULL,
        "description" text,
        "price" numeric(12,2) NOT NULL,
        "stock" integer NOT NULL DEFAULT 0,
        "is_available" boolean NOT NULL DEFAULT true,
        "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_products_store_id" ON "products" ("store_id")
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_products_category_id" ON "products" ("category_id")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "products"`);
    await queryRunner.query(`DROP TABLE "categories"`);
  }
}
