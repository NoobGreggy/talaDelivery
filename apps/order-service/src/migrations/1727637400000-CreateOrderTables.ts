import { MigrationInterface, QueryRunner } from 'typeorm';

export class CreateOrderTables1727637400000 implements MigrationInterface {
  name = 'CreateOrderTables1727637400000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "orders" (
        "id" SERIAL PRIMARY KEY,
        "order_number" character varying(30) NOT NULL UNIQUE,
        "customer_id" integer NOT NULL,
        "store_id" integer NOT NULL,
        "delivery_id" integer,
        "status" character varying(20) NOT NULL DEFAULT 'PENDING',
        "payment_method" character varying(10) NOT NULL DEFAULT 'COD',
        "payment_status" character varying(20) NOT NULL DEFAULT 'PENDING',
        "subtotal" numeric(12,2) NOT NULL,
        "discount" numeric(12,2) NOT NULL DEFAULT 0.00,
        "delivery_fee" numeric(12,2) NOT NULL DEFAULT 0.00,
        "total" numeric(12,2) NOT NULL,
        "pickup_address" text,
        "pickup_latitude" character varying(20),
        "pickup_longitude" character varying(20),
        "delivery_address" text,
        "delivery_latitude" character varying(20),
        "delivery_longitude" character varying(20),
        "customer_name" character varying(160) NOT NULL,
        "customer_phone" character varying(40),
        "store_name" character varying(160) NOT NULL,
        "store_snapshot" jsonb,
        "cancelled_by" character varying(30),
        "cancellation_reason" text,
        "cancelled_at" TIMESTAMPTZ,
        "created_at" TIMESTAMPTZ NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(`CREATE UNIQUE INDEX "UQ_orders_order_number" ON "orders" ("order_number")`);
    await queryRunner.query(`CREATE INDEX "IDX_orders_customer_id" ON "orders" ("customer_id")`);
    await queryRunner.query(`CREATE INDEX "IDX_orders_store_id" ON "orders" ("store_id")`);
    await queryRunner.query(`CREATE INDEX "IDX_orders_status" ON "orders" ("status")`);
    await queryRunner.query(`
      CREATE TABLE "order_items" (
        "id" SERIAL PRIMARY KEY,
        "order_id" integer NOT NULL,
        "product_id" integer NOT NULL,
        "product_name" character varying(200) NOT NULL,
        "quantity" integer NOT NULL,
        "unit_price" numeric(12,2) NOT NULL,
        "subtotal" numeric(12,2) NOT NULL,
        "created_at" TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(`CREATE INDEX "IDX_order_items_order_id" ON "order_items" ("order_id")`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "order_items"`);
    await queryRunner.query(`DROP TABLE "orders"`);
  }
}
