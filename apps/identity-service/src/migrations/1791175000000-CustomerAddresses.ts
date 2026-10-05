import { MigrationInterface, QueryRunner } from 'typeorm';
export class CustomerAddresses1791175000000 implements MigrationInterface {
  async up(runner: QueryRunner): Promise<void> {
    await runner.query(`CREATE TABLE IF NOT EXISTS customer_addresses (
      id SERIAL PRIMARY KEY, user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      label varchar(80) NULL, recipient_name varchar(160) NOT NULL, phone varchar(40) NOT NULL,
      address_line text NOT NULL, barangay varchar(120) NULL, city varchar(120) NOT NULL,
      province varchar(120) NOT NULL, postal_code varchar(20) NULL, latitude numeric(10,7) NULL,
      longitude numeric(10,7) NULL, notes text NULL, is_default boolean NOT NULL DEFAULT false
    )`);
    await runner.query('CREATE INDEX IF NOT EXISTS customer_addresses_user_idx ON customer_addresses(user_id)');
  }
  async down(runner: QueryRunner): Promise<void> { await runner.query('DROP TABLE customer_addresses'); }
}
