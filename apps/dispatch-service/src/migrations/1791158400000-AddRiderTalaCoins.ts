import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddRiderTalaCoins1791158400000 implements MigrationInterface {
  async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE riders ADD COLUMN IF NOT EXISTS tala_coins_balance numeric(12,2) NOT NULL DEFAULT 0`);
    await queryRunner.query(`ALTER TABLE delivery_zones ADD COLUMN IF NOT EXISTS tala_coins_percent numeric(5,2) NOT NULL DEFAULT 0`);
    await queryRunner.query(`ALTER TABLE delivery_zones ADD CONSTRAINT delivery_zones_coins_percent_range CHECK (tala_coins_percent BETWEEN 0 AND 100)`);
    await queryRunner.query(`ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS delivery_zone_id integer NULL`);
    await queryRunner.query(`ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS tala_coins_percent numeric(5,2) NOT NULL DEFAULT 0`);
    await queryRunner.query(`CREATE TABLE IF NOT EXISTS rider_coin_transactions (
      id SERIAL PRIMARY KEY, rider_id integer NOT NULL REFERENCES riders(id),
      delivery_id integer NULL UNIQUE REFERENCES deliveries(id), request_id uuid NULL UNIQUE,
      type varchar(20) NOT NULL, amount numeric(12,2) NOT NULL, balance_after numeric(12,2) NOT NULL,
      deduction_percent numeric(5,2) NULL, delivery_zone_id integer NULL, actor_id integer NULL,
      note varchar(500) NULL, admin_alert_pending boolean NOT NULL DEFAULT false,
      created_at timestamptz NOT NULL DEFAULT now()
    )`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS rider_coin_transactions_rider_history ON rider_coin_transactions (rider_id, id)`);
    await queryRunner.query(`CREATE INDEX IF NOT EXISTS rider_coin_transactions_alert_pending ON rider_coin_transactions (admin_alert_pending)`);
  }
  async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE rider_coin_transactions`);
    await queryRunner.query(`ALTER TABLE deliveries DROP COLUMN tala_coins_percent, DROP COLUMN delivery_zone_id`);
    await queryRunner.query(`ALTER TABLE delivery_zones DROP CONSTRAINT delivery_zones_coins_percent_range, DROP COLUMN tala_coins_percent`);
    await queryRunner.query(`ALTER TABLE riders DROP COLUMN tala_coins_balance`);
  }
}
