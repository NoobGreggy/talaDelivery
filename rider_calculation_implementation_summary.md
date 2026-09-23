# Rider calculation implementation summary

Implemented September 23, 2026 across the TalaDelivery API, admin application,
and rider Flutter application.

## Result

Rider earnings are now separate from the customer delivery fee. The platform
admin can change the commission and earnings-period rules without rebuilding
the API or mobile application. Each new delivery stores a snapshot of the
commission rule and amount, so later admin changes do not alter existing work.

Commission is counted as earned only when a delivery has status `DELIVERED`.
Assigned, accepted, picked-up, in-transit, failed, and cancelled deliveries are
excluded from rider totals.

## Dynamic admin settings

The Admin **Settings** page now reads and writes `/api/v1/admin/settings`.

Available settings:

- commission type: percentage of delivery fee or fixed amount;
- commission value;
- earnings week: rolling seven days or calendar week;
- calendar week start day;
- settlement timezone;
- daily settlement start/cutoff time;
- distance calculation method.

Safe database defaults are:

```text
commission type: PERCENTAGE
commission value: 0
week type: ROLLING_SEVEN_DAYS
week starts on: Monday
timezone: Asia/Manila
daily cutoff starts: 00:00
distance method: STRAIGHT_LINE
```

The admin must set the intended non-zero commission value before creating live
orders. A zero default avoids inventing a financial rate during deployment.

## API changes

- Added a singleton `platform_settings` record and protected admin GET/PUT
  endpoints.
- Added `rider_commission`, `commission_type`, and `commission_value` snapshots
  to deliveries.
- New orders calculate their commission from the current admin setting.
- Rider and admin earnings aggregates now sum `rider_commission`, not the
  customer-facing `delivery_fee`.
- Added `/api/v1/rider/earnings-summary`, returning server-calculated today,
  week, and month boundaries, delivery counts, and earnings.
- Rider profile, online, offline, and location responses now return consistent
  completed-delivery and earnings aggregates.
- Checkout now requires delivery latitude, longitude, and city.
- Missing pickup/drop-off coordinates return a clear validation/domain error
  instead of being converted to `(0, 0)`.
- Pricing selects the active city-wide zone using normalized city text.
- Checkout declines unmatched cities instead of using an unrelated zone or
  hidden hard-coded fee.
- Admin cannot create or activate two city-wide zones for the same normalized
  city through the API.
- Offer responses include `duration_seconds`, removing the rider app's separate
  hard-coded countdown duration.

## Admin application changes

- Replaced the static Settings save behavior with real API-backed settings.
- Added commission, earnings period, timezone, cutoff, and distance controls.
- Made city required when configuring a delivery zone.
- Changed the misleading zone card label to **Newest Zone Base Fee**.
- Loads up to 1,000 zones so the current client-side counts and filters cover
  normal platform usage.
- Corrected delivery distance from `distance` to the API field `distance_km`.
- Added the snapshotted rider commission to delivery details.

## Rider Flutter changes

- Parses customer delivery fee and rider commission as separate values.
- Parses `created_at` and `delivered_at` as separate timestamps.
- Offers show **estimated commission** and **delivery distance**, not the full
  customer fee or an incorrectly labelled total-trip distance.
- Completion, history rows, dashboard earnings, and history earnings display
  `rider_commission`.
- Dashboard/history period boundaries and totals come from the server earnings
  summary, using the admin-configured timezone and cutoff.
- The local rolling-week fallback now rejects future timestamps.
- Offer progress uses the duration supplied by the API.

## Historical data behavior

Existing delivery fees and distances are unchanged. Existing completed
deliveries are not automatically assigned a rider commission because there is
no reliable historical commission rule to apply. If historical commissions
must be imported, perform a separate reviewed backfill using the actual past
business rates.

## Remaining limitations

1. `STRAIGHT_LINE` is currently the only supported distance method. Road-route
   distance requires selecting and configuring a routing provider; the admin
   cannot select an unimplemented method.
2. Zone uniqueness is enforced by API validation. If multiple processes will
   write directly to the database, add a database-level normalized active-city
   constraint appropriate to the production database.
3. The admin zone screen requests up to 1,000 zones. True server-side zone
   pagination should replace this if the platform approaches that scale.

## Deployment and setup

From `tala_delivery_api`:

```bash
php artisan migrate
php artisan optimize:clear
```

Then sign in as platform admin, open **Settings**, and configure the intended
commission value, period rule, timezone, and cutoff before accepting live
orders. Existing application processes should be restarted after migration.

## Verification completed

- Laravel Pint: passed.
- Laravel full test suite: 71 tests and 361 assertions passed.
- Flutter full test suite: 32 tests passed.
- Flutter static analysis: no issues found.
- Angular production build: passed.
- `git diff --check`: passed for API, admin, and rider repositories.

No commits or pushes were performed.
