// Exercise the real notification writer without publishing any jobs or messages.
require('dotenv').config({ quiet: true });
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { DataSource } = require('typeorm');
const { Notification } = require('../apps/notification-service/src/entities/notification.entity');
const { NotificationService } = require('../apps/notification-service/src/services/notification.service');

async function main() {
  const host = process.env.POSTGRES_HOST ?? 'localhost';
  assert(['localhost', '127.0.0.1', '::1'].includes(host), 'Only local databases are supported by this test.');
  const schema = `coin_notification_test_${randomUUID().replaceAll('-', '')}`;
  const dataSource = new DataSource({ type: 'postgres', host, port: Number(process.env.POSTGRES_PORT ?? 5432),
    username: process.env.POSTGRES_USER, password: process.env.POSTGRES_PASSWORD,
    database: 'taladelivery_notification', schema, entities: [Notification], synchronize: false });
  await dataSource.initialize();
  const runner = dataSource.createQueryRunner();
  await runner.connect();
  await runner.startTransaction();
  try {
    await runner.query(`CREATE SCHEMA ${schema}`);
    await runner.query(`CREATE TABLE ${schema}.notifications (LIKE public.notifications INCLUDING ALL)`);
    await runner.query(`CREATE SEQUENCE ${schema}.notification_ids`);
    await runner.query(`ALTER TABLE ${schema}.notifications ALTER COLUMN id SET DEFAULT nextval('${schema}.notification_ids')`);
    const repository = runner.manager.getRepository(Notification);
    const service = new NotificationService(repository);
    const input = { userId: 1, sourceKey: 'rider-coins:test:1', type: 'admin.rider_coins_negative',
      title: 'Negative Tala Coins balance', body: 'Test only', data: { riderId: 5, balance: '-5.00', phone: 'test-contact' } };
    const first = await service.create(input);
    await repository.update({ id: first.id }, { isRead: true });
    const second = await service.create(input);
    assert.equal(first.id, second.id);
    assert.equal(await repository.count(), 1);
    assert.deepEqual(second.data, input.data);
    assert.equal(second.isRead, true, 'A retry must preserve the read state');
    assert.equal(second.sourceKey, input.sourceKey);
    console.log('PASS: real NotificationService stores JSON contact details, deduplicates retries, and preserves read state.');
  } finally {
    await runner.rollbackTransaction();
    await runner.release();
    await dataSource.destroy();
  }
}

main().catch((error) => { console.error(error.message); process.exitCode = 1; });
