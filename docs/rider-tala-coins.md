# Rider Tala Coins

Admins configure **Rider Tala Coins deduction (%)** on each delivery zone (0–100,
up to two decimals). The calculation is `delivery fee × percentage / 100`,
rounded to two decimals. A PHP 100 delivery fee at 10% deducts 10.00 coins.
The percentage and zone are preserved on the delivery when it is created.
Changing the zone does not change an existing delivery's deduction.

The deduction is recorded only on successful completion, in the same database
transaction as the delivery status. A locked status check and unique delivery
ledger entry prevent duplicate deductions. Cancellation does not charge coins.
Rider commission calculations and earnings are independent of this balance.

Balances can go negative; availability and delivery acceptance are not blocked.
When a balance crosses from zero or above to below zero, active platform admins
receive an `admin.rider_coins_negative` notification with the rider's name,
phone, balance, and delivery. Further deductions while negative do not create
another crossing alert. A top-up returning the balance to zero or above enables
an alert on the next negative crossing. Admin notifications refresh every 15 seconds.

An alert-pending flag is persisted with the ledger entry. Dispatch retries pending
alerts every 10 seconds; a notification source key deduplicates queue retries.
No active admins or unavailable identity/notification queues leave the alert pending.

In **Riders → rider details**, admins can add Tala Coins with an optional payment
reference/note, view paginated transactions, and call a rider with a negative balance.
Top-ups use a UUID request key so retrying the same request credits only once.

## Database rollout

Development uses TypeORM synchronization on service restart. Production uses
migrations against the existing dispatch and notification schemas:

```sh
npm run migration:run:notification
npm run migration:run:dispatch
```

Deploy/restart identity, notification, order, and dispatch services and rebuild the
admin app. The dispatch migration discovery path now matches `src/migrations`.
Existing rider balances and zone percentages start at zero; existing deliveries
also keep a zero percentage. Historical deliveries are not charged retroactively.
Set the required percentages in Delivery Zones before placing new orders.

Admin-only endpoints:

- `GET /admin/riders/:id/coins?page=1&per_page=20`
- `POST /admin/riders/:id/coins/top-up` with `{ "amount": "100.00", "request_id": "<UUID v4>", "note": "Payment reference" }`

Rider resources include `tala_coins_balance`; zone create/update/resources include
`tala_coins_percent`. Zone numeric write fields use decimal strings.

## Verification

Focused Jest tests cover percentage validation, deduction rounding, negative
crossings, top-up retries, completion races, and pending-alert retries. Additional
local PostgreSQL checks run in temporary schemas and roll back their rows:

```sh
node -r ts-node/register test/rider-coins-migrations.cjs
node -r ts-node/register test/rider-coins-notifications.cjs
node test/rider-coins-readiness.cjs
```

The notification test calls the writer directly; it does not enqueue messages.
The readiness script is read-only and expects the local services to be running.
