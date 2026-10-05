require('dotenv').config({ quiet: true });
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { DataSource } = require('typeorm');
const { Store } = require('../apps/merchant-service/src/entities/store.entity');
const { StoreCategory } = require('../apps/merchant-service/src/entities/store-category.entity');
const { StoreCategoryService } = require('../apps/merchant-service/src/services/store-category.service');
const { AddStoreCategories1791162000000 } = require('../apps/merchant-service/src/migrations/1791162000000-AddStoreCategories');
const { StoreCategoryIcons1791176000000 } = require('../apps/merchant-service/src/migrations/1791176000000-StoreCategoryIcons');

async function main() {
  const host = process.env.POSTGRES_HOST ?? 'localhost';
  assert(['127.0.0.1', 'localhost', '::1'].includes(host), 'Only local databases are allowed for this test.');
  const schema = `category_test_${randomUUID().replaceAll('-', '')}`;
  const ds = new DataSource({ type: 'postgres', host, port: Number(process.env.POSTGRES_PORT ?? 5432),
    username: process.env.POSTGRES_USER, password: process.env.POSTGRES_PASSWORD,
    database: 'taladelivery_merchant', schema, entities: [Store, StoreCategory], synchronize: false });
  await ds.initialize();
  const runner = ds.createQueryRunner(); await runner.connect(); await runner.startTransaction();
  try {
    await runner.query(`CREATE SCHEMA ${schema}`);
    await runner.query(`SET LOCAL search_path TO ${schema}`);
    await runner.query(`CREATE TABLE ${schema}.stores (LIKE public.stores INCLUDING ALL)`);
    await runner.query(`CREATE SEQUENCE ${schema}.store_ids`);
    await runner.query(`ALTER TABLE ${schema}.stores ALTER COLUMN id SET DEFAULT nextval('${schema}.store_ids')`);
    const migration = new AddStoreCategories1791162000000(); await migration.up(runner);
    const iconMigration = new StoreCategoryIcons1791176000000(); await iconMigration.up(runner);
    const service = new StoreCategoryService({ transaction: async (callback) => callback(runner.manager) }, runner.manager.getRepository(StoreCategory));
    const stores = runner.manager.getRepository(Store);
    const store = await stores.save(stores.create({ name: 'Category Test Store', slug: 'category-test-store' }));
    const restaurant = await service.save({ name: '  Restaurants  ', is_active: true });
    const pharmacy = await service.save({ name: 'Pharmacy', is_active: true, icon: 'medication_rounded' });
    assert.equal(pharmacy.icon, 'medication_rounded');
    assert.equal(restaurant.name, 'Restaurants');
    await runner.query('SAVEPOINT duplicate_category');
    await assert.rejects(service.save({ name: ' restaurants ', is_active: true }), /already exists/);
    await runner.query('ROLLBACK TO SAVEPOINT duplicate_category');
    await service.tagStore(store.id, [restaurant.id, pharmacy.id]);
    assert.equal((await stores.findOneByOrFail({ id: store.id })).categories.length, 2);
    const listed = await service.list();
    assert.equal(listed.find((category) => category.id === restaurant.id).store_count, 1);
    await service.save({ name: 'Pharmacy', is_active: false }, pharmacy.id);
    assert.equal((await service.list()).find((category) => category.id === pharmacy.id).icon, 'medication_rounded');
    assert(!(await service.list(true)).some((category) => category.id === pharmacy.id));
    await service.tagStore(store.id, [restaurant.id, pharmacy.id]); // preserve an existing inactive tag
    await service.tagStore(store.id, [restaurant.id]);
    await assert.rejects(service.tagStore(store.id, [restaurant.id, pharmacy.id]), /Inactive categories/);
    await assert.rejects(service.tagStore(store.id, [restaurant.id, 999999]), /no longer exist/);
    assert.equal((await stores.findOneByOrFail({ id: store.id })).categories.length, 1);
    await service.tagStore(store.id, []);
    assert.equal((await stores.findOneByOrFail({ id: store.id })).categories.length, 0);
    await iconMigration.down(runner);
    await migration.down(runner);
    console.log('PASS: category normalization/uniqueness, multiple store tags, counts, inactive customer filtering, invalid tag rejection, clearing tags and migration rollback.');
  } finally { await runner.rollbackTransaction(); await runner.release(); await ds.destroy(); }
}
main().catch((error) => { console.error(error.message); process.exitCode = 1; });
