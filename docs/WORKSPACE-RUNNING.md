# Running TalaDelivery locally

## Prerequisites

Two things must be up before anything works. Check them first:

```powershell
Test-NetConnection 127.0.0.1 -Port 5433   # Postgres  -> True
Test-NetConnection 127.0.0.1 -Port 6380   # Redis     -> True
```

Redis is on **6380** (not the default 6379) â€” it is set in `.env` as
`REDIS_PORT=6380`. Several services silently fall back to `6379` if the
variable is missing, which fails in a confusing way, so check it.

## The one command

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\Gregg\system\talaDelivery\start.ps1
```

Starts the API (9 processes) and both frontends, then waits until each is
actually answering. Takes **~4 minutes** on first run.

Open **http://localhost:4200**.

| | URL | Login |
|---|---|---|
| Admin | http://localhost:4200 | `admin@taladelivery.com` / `Admin@123456` |
| Merchant | http://localhost:4300 | `storeadmin@test.com` / `Store@123456` |
| API | http://localhost:3000/api/v1 | â€” |
| Realtime | ws://localhost:3008/realtime | â€” |

Stop:

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\Gregg\system\talaDelivery\stop.ps1
```

### Options

```powershell
# API only, no frontends
powershell -ExecutionPolicy Bypass -File C:\Users\Gregg\system\talaDelivery\start.ps1 -NoFrontend

# API + admin only
powershell -ExecutionPolicy Bypass -File C:\Users\Gregg\system\talaDelivery\start.ps1 -NoMerchant
```

## Running the API by hand

You need **9 terminal windows** â€” one per service. In each:

```powershell
cd C:\Users\Gregg\system\talaDelivery\taladelivery-backend
```

Then one command per window:

```powershell
node -r ts-node/register -r tsconfig-paths/register apps/api-gateway/src/main.ts
node -r ts-node/register -r tsconfig-paths/register apps/identity-service/src/main.ts
node -r ts-node/register -r tsconfig-paths/register apps/merchant-service/src/main.ts
node -r ts-node/register -r tsconfig-paths/register apps/catalog-service/src/main.ts
node -r ts-node/register -r tsconfig-paths/register apps/order-service/src/main.ts
node -r ts-node/register -r tsconfig-paths/register apps/dispatch-service/src/main.ts
node -r ts-node/register -r tsconfig-paths/register apps/payment-service/src/main.ts
node -r ts-node/register -r tsconfig-paths/register apps/notification-service/src/main.ts
node -r ts-node/register -r tsconfig-paths/register apps/realtime-service/src/main.ts
```

No environment variables are needed. Each service reads `.env` and falls back
to its own database, so **do not** set a global `POSTGRES_DB_NAME` â€” that
silently points every service at one database.

Then the frontends, in two more windows:

```powershell
cd C:\Users\Gregg\system\talaDelivery\talaDelivery-admin
npm.cmd start
```

```powershell
cd C:\Users\Gregg\system\talaDelivery\talaDelivery-merchant
npm.cmd start
```

Use `npm.cmd`, not `npm` â€” PowerShell resolves `npm` to `npm.ps1`, which the
execution policy blocks.

### Why the script is better

11 windows is easy to get wrong, and a missing service does not fail loudly.
It also staggers startup: launching all 9 at once exhausted memory and silently
killed the last one with `Zone Allocation failed - process out of memory`.

## Frontends on their own

The Angular apps proxy through `proxy.conf.json`, so no extra flags:

| Path | Proxied to |
|---|---|
| `/api` | api-gateway :3000 |
| `/socket.io` | realtime-service :3008 |

Both are same-origin, so no CORS setup is required. Override a busy port with
`ng serve --port 4201` (admin) or `--port 4301` (merchant).

## Logs

| What | Where |
|---|---|
| Backend | `taladelivery-backend\.logs\<service>.log` (and `.err.log`) |
| Frontends | `.devlogs\admin.log`, `.devlogs\merchant.log` |

The realtime service logs `worker <queue> redis error:` on every reconnect
attempt while Redis is down. A few of those are fine; a steady stream means
Redis is unreachable.

## Tests

Backend, from `taladelivery-backend`:

```powershell
npm.cmd run test:all                       # 108 unit tests
npm.cmd run typecheck                      # 9 projects

node test/reset-fixtures.mjs               # restore stock, clear stale offers
node test/e2e-flow.mjs                     # 23  customer / merchant / admin
node test/rider-flow.mjs                   # 48  rider lifecycle + events
node test/admin-merchant-flow.mjs          # 33  role-scoped feeds
node test/gateway-frontend-contract.mjs    # 27  gateway + Socket.IO rooms
node test/inspect-queues.mjs               # per-queue job counts
```

Run `reset-fixtures.mjs` before a flow test â€” order creation decrements product
stock, and a few runs will otherwise exhaust it and fail with "Insufficient
stock", which looks like a product bug.

Frontends:

```powershell
npm.cmd run build
```

## When something is broken

| Symptom | Cause |
|---|---|
| `500` on every API call from the browser | The backend is not running, or a service is missing. Check `netstat -ano \| findstr :300`. |
| `403` right after login | identity-service (3001) is down â€” the gateway forwards login but the JWT check has nowhere to go. |
| Notification bell never goes live | realtime-service (3008) is down. `start.ps1` needs `START_REALTIME=1`; the one-command version sets it for you. |
| Empty store/product lists | catalog (3003) or merchant (3002) down. |
| "Insufficient stock" in tests | Run `node test/reset-fixtures.mjs`. |
| `EADDRINUSE` | Run `stop.ps1` first. |
| Blank page, no data | Open the browser console; the app talks to `/api` on its own origin. |
| Port already in use (Angular) | `ng serve --port 4201`. |

Quick health check for all nine:

```powershell
3000..3008 | ForEach-Object { $p = $_; try { $r = Invoke-RestMethod "http://localhost:$p/health/live" -TimeoutSec 2; "$p UP" } catch { "$p DOWN" } }
```

## Admin order monitoring and store categories

- Orders is a read-only monitor for all order statuses. Status/search filters
  apply to the full list on the server. The list and detail refresh on realtime
  events, with a 10-second refresh fallback while the page is visible.
- Catalog > Categories replaces the admin Products menu. Create/edit categories
  there, then open Stores > a store > Categories to select multiple tags and save.
  Existing product records and merchant product management are unchanged.
- Deactivated categories keep existing store tags but are hidden from the
  customer category list and cannot be added to another store.
- Customer-app integration is deferred. The prepared read-only endpoint is
  `GET /api/v1/store-categories`, with `X-App-Key` and no customer login required.
  The response envelope's `data` is an array of active categories, sorted by name,
  with `id`, `name`, `description`, `is_active`, `store_count`, `created_at`, and
  `updated_at`. Stores expose their category tags; customers can optionally use
  `GET /api/v1/stores?category=<category-id>` to list active stores in that category.
- Admin endpoints (platform-admin login required):
  `GET/POST /api/v1/admin/store-categories`,
  `PUT /api/v1/admin/store-categories/<id>`, and
  `PUT /api/v1/admin/stores/<id>/categories` with
  `{ "category_ids": [1, 2] }` (send `[]` to clear tags).
- Development registers the new category tables on merchant-service startup.
  For production, apply `npm.cmd run migration:run:merchant` before deploying.

Verification from `taladelivery-backend`:

```powershell
node test/admin-orders-monitor.mjs
node -r ts-node/register -r tsconfig-paths/register test/store-categories-db.cjs
```

The first check reads the running API without changing orders or tags. The
second checks category/tag behavior in an isolated PostgreSQL transaction and
rolls it back, leaving no test rows.

## Notes

## Merchant on the NestJS delivery API

The merchant app is based on remote `features/merchant` commit `82dbdc4`.
Previous local preview edits are saved, not reapplied, in Git stash
`merchant-preview-before-repo-update-2026-10-05` inside `talaDelivery-merchant`.

- Open `http://localhost:4300` and sign in again after changing backends.
- Development uses `/api/v1` through port 3000 and Socket.IO `/realtime` through
  port 3008. The merchant has no Echo, Pusher, Reverb, or broadcasting-auth setup.
- Orders, products, product categories, and store profile use `/api/v1/store/*`
  endpoints. Membership is checked on the server for reads and writes.
  Merchant product categories remain separate from platform store-category tags.
- Confirm, preparing, ready, and cancel actions use the existing order/dispatch
  lifecycle. Order detail includes the delivery status and assigned rider's
  name/phone. Status/search filters apply before pagination; the list and detail
  refresh on order events and have a 10-second visible-page fallback.
- Login resolves store membership via `/store/profile`, because the identity
  login response does not include store snapshots. Socket subscription replies
  use the standard API envelope. Only verified members can join a merchant room.
- Settings save the store name, description, email, phone, address and daily
  opening/closing times. Product SKU/image fields are persisted by catalog.
- The notification bell reads and marks read the current user's feed only.
- Production serves the built merchant app behind an ingress that forwards
  `/api` to `api-gateway:3000` and `/socket.io` (including WebSocket upgrades)
  to `realtime-service:3008`. Both Angular environments now use same-origin URLs.
  Configure the merchant `appKey` to match the backend `APP_API_KEY` for deployment.
- Production deployments must run the merchant and catalog migrations for the
  added profile/SKU/image fields. Compose's migrate service runs all migrations.
  The Dockerfile uses Nest project names and the actual nested compiled entrypoint.
  Docker runtime was not tested locally because Docker is not installed.

Read-only connection check, from `taladelivery-backend`:

```powershell
node test/merchant-api-connection.mjs
```

## General notes

### Customer phone and merchant realtime test (LAN)

Product visibility fix (2026-10-06): customer store details now fetch and combine
the Nest store snapshot, product categories and every page of that store's
available products. Previously the mobile page expected products embedded in
the store snapshot and therefore showed an empty menu. Install the rebuilt
customer APK over the previous version to pick up this app-side fix.

Existing `Test Store` (ID 1) was reused without renaming or replacing its data.
The `storeadmin@test.com` merchant already owns it. Added sample menu categories
`Sample Meals` and `Sample Drinks`, and three available products with stock 50:
Sample Classic Burger (PHP 99), Sample Chicken Rice Meal (PHP 149), and Sample
Iced Tea (PHP 49). The existing product remains untouched. No orders were placed.
Seed script `taladelivery-backend/test/seed-sample-store.mjs` reuses matching
sample entries rather than creating duplicates or overwriting their values.

Catalog explicitly parses ordinary JSON requests after the scoped 8 MiB product
parsers; without that fallback Nest skipped JSON parsing for category requests.
Category creation and the 5 MiB image transport limit have both been checked.

- Current Ethernet IP (2026-10-05): `192.168.100.18`.
- Customer `config/local.json` uses `http://192.168.100.18:3000/api/v1/`
  and `TALA_SOCKET_IO_URL=http://192.168.100.18:3008`. Its API key matches
  backend `APP_API_KEY`. Keep this local file private; do not commit it.
- Install `talaDelivery-customer/build/app/outputs/flutter-apk/app-debug.apk`
  on your Android phone. Connect the phone to the same LAN/Wi-Fi as this PC.
  Sign out/in after switching from the old API. Save a delivery address with
  a map pin inside an active delivery zone, then order from the store you
  have open in the merchant console at `http://localhost:4300` on this PC.
- Merchant orders and the notification bell should refresh for that store.
  LAN login, read-only browsing, saved-address listing, customer Socket.IO
  and merchant Socket.IO subscriptions have been checked. No real orders were
  placed for verification; no Android phone was attached for installation.
- If your phone cannot reach the API, check Wi-Fi client isolation and Windows
  private-network firewall access to ports 3000 and 3008. No firewall rules
  were changed. Rebuild after changing the PC IP in `config/local.json`:

```powershell
cd C:\Users\Gregg\system\talaDelivery\talaDelivery-customer
C:\php\flutter\bin\flutter.bat build apk --debug --dart-define-from-file=config/local.json
```

- Customer checkout now sends Nest order fields, parses camelCase responses,
  and uses authenticated Socket.IO `/realtime` rather than Reverb. Identity
  now provides user-scoped saved-address CRUD. Public products expose photos
  and filter by store/category/search; nested store catalog routes go to catalog.
- Production must run identity and order migrations for customer addresses
  and order notes, plus the merchant migration for category icons.

### Admin category icons shared with Flutter

- Admin Catalog > Categories > Add/Edit now includes visual icon choices using
  the same bundled Material icon font as Flutter: Food, Groceries, Pharmacy,
  Parcel, Deals, and General. The category's `icon` key is stored in
  `taladelivery_merchant.store_categories.icon` and returned on store tags.
- `GET /api/v1/admin/store-categories/icons` lists allowed keys (admin JWT).
  `GET /api/v1/store-categories` lists active customer categories with `icon`
  (app key required, no login). Create/update category accepts `icon`; unknown
  keys are rejected. Merchant product categories remain a separate taxonomy.
- Customer home loads active platform categories directly, including unassigned
  categories, and maps the icon key to constant Flutter `Icons.*` values.
  Selecting a category filters stores by their assigned platform tags. Unknown
  keys fall back safely to the existing category appearance.

```powershell
# Read-only LAN/API checks from taladelivery-backend (uses existing test customer).
node test/customer-lan-connection.mjs
```

### Customer checkout delivery fee from admin zones (2026-10-06)

Cart update (2026-10-06): delivery pricing is now calculated on the cart page
before continuing. Cart loads saved addresses, selects the default (or a chosen
address), requests the same zone quote, and shows a numeric delivery fee and full
total. Checkout is disabled while calculating or if coverage fails; address
changes recalculate, stale results are ignored, and quantity changes update the
subtotal/total. Cart refreshes the quote before proceeding and passes the selected
address ID into checkout. No `Calculated by API` placeholder is shown in cart.
All 63 Flutter tests passed, including cart totals, address handoff, loading,
stale-response handling, coverage retry and missing-address behavior.

Diagnosis before the approved data fix: customer test account's default delivery address is in
Cauayan, Isabela. Zone ID 2 covers Cauayan but is ARCHIVED; zone ID 1 in Makati
is also ARCHIVED. Test Store ID 1 remains in Makati. Zone status and store
location changes required a user decision and were initially left unchanged.

Approved sample-data repair (2026-10-06): zone ID 2 is now named `Cauayan Zone`
and ACTIVE. Its existing Cauayan/Isabela boundary and all pricing/coin rates were
preserved. Test Store ID 1 was moved to an explicitly labelled sample pickup
location in Cauayan, about 0.22 km from the test customer's saved address,
at latitude `16.9452107`, longitude `121.7662783`. Its previous pickup was
`123 Test Street, Makati City`, latitude `14.5547000`, longitude `121.0244000`.
The live API verified a PHP 50.00 delivery quote: PHP 50 base fee includes 5 km,
then PHP 10 per extra km using the zone's existing rounding rules. All four
products, store membership and existing orders were preserved; no orders were
created. Makati zone ID 1 remains ARCHIVED. Refresh the app/cart or tap Retry
delivery fee to fetch the corrected data; no further APK change is required.

- Admin > Delivery Zones controls the customer fee: base fee, included distance,
  extra fee per kilometre, rounding increment, optional maximum distance and fee
  cap. The existing dispatch PricingService remains the single calculator for
  both checkout estimates and order creation. Only ACTIVE zones with an effective
  date that has arrived qualify; boundary zones must cover the delivery pin.
- `POST /api/v1/orders/delivery-quote` requires app key + customer JWT. Send
  `{ "storeId": 1, "deliveryLatitude": "14.557", "deliveryLongitude": "121.027",
  "city": "Makati City", "province": "Metro Manila" }`.
  Success includes `deliveryFee`, `distanceKm`, `billableDistanceKm`,
  `distanceMethod`, and `zone: { id, name }` in the standard envelope. This endpoint
  does not create orders, deliveries, reservations or notifications.
- Pickup coordinates come from the server's store record, not customer-supplied
  overrides. Order creation stores those same pickup coordinates and recalculates
  the fee and product subtotal on the server. Client fee/total fields are not trusted.
- Customer checkout loads the quote for the selected address and shows zone,
  distance, delivery fee and subtotal + delivery total. It refreshes on address
  changes and before confirmation, ignores stale responses, and disables ordering
  during calculation or when coverage/location/distance validation fails. Retry
  is available if the quote fails. Rider Tala-coin percentages are not added to
  the customer's fee.
- Both saved zones were ARCHIVED before the approved sample-data repair above.
  Cauayan zone ID 2 is now ACTIVE; pricing rates were not changed. In Admin > Delivery Zones, edit the intended zone and set Lifecycle
  status to Active (or create an active zone) to serve the customer's location.
  Test Store is now in Cauayan; its delivery address must fall within the active coverage.
- Reinstall the latest customer debug APK for this checkout feature. Flutter
  analysis and all 58 tests passed; backend typechecking and all 199 tests passed.
  Live quote authentication, coordinate validation, unavailable-zone response and
  no-order side effects were checked via the LAN API.

### Product photos, notifications, and category scopes

- Merchant Products > Add/Edit > Photo accepts PNG, JPEG, GIF and WebP files
  up to 5 MiB (5 x 1024 x 1024 bytes). The browser converts to a Base64 data URL
  and previews it; catalog persists the image in `products.image` (text).
  Save waits for conversion. Remove Photo clears the stored value when saved.
  SVG is not accepted. Catalog validates MIME/signature and decoded size.
  Only product upload routes have an 8 MiB JSON limit for Base64 expansion.
- A new order queues `order.received` for every member of its store. After the
  notification is persisted, notification-service emits `notification.created`
  to that member's user room; the merchant bell reloads the persisted feed and
  its unread count. No order or notification test messages were sent to users.
- Admin Catalog > Categories manages store classification tags. In admin,
  Stores > a store > Categories lists active admin categories for checkbox
  selection; Save Categories assigns them to that store. Merchant Categories
  instead manages that merchant store's own product categories. They are two
  separate lists and each product/category request checks store membership.

```powershell
# From taladelivery-backend; invalid product names prevent saving test rows.
node test/product-image-limit.mjs
```

- `npm run build` is **not** a sufficient check â€” it has passed while
  `ts-node` failed at boot on the same file. Use `npm run typecheck`.
- The first `start.ps1` after a reboot compiles all 9 services, so it is slow.
  Later runs are the same speed; nothing is cached.
- The API gateway has no database of its own and is the single entry point for
  both frontends. If `/api` 404s on the gateway itself, the proxy middleware
  is not mounted â€” see the gateway notes in `nestjs_api.md`.

### Rider app: Nest API and realtime (2026-10-06)

- The rider app now uses the Nest gateway, not Laravel/Reverb.
  Private `talaDelivery-rider/config/local.json` targets
  `http://192.168.100.18:3000/api/v1/` and Socket.IO
  `http://192.168.100.18:3008/realtime`. The app key matches the backend;
  the config is ignored by Git. Update this file and rebuild if the PC IP changes.
- Login stores access and rotating refresh JWTs in secure storage. HTTP calls
  refresh expiring tokens and retry authentication once. Realtime reads a fresh
  JWT on each reconnect and joins only the signed-in rider's `user:<userId>`
  room. A successful room acknowledgment is required before reporting connected.
- Dispatch now publishes `delivery.offered`, `delivery.updated`, and
  `offer.updated` to the rider's identity user room through `realtime-feed`.
  New offers also queue a persistent rider notification; notification-service
  broadcasts `notification.created` after saving it. Expired, rejected,
  manually superseded, and cancelled offers refresh the offer list.
- Rider offer/delivery lists now hydrate the order and store. Flutter parses
  Nest order numbers, customer contacts, product names/prices, and notification
  `body` correctly. Location reporting continues through authenticated
  `POST /rider/location`, including ownership checks for tracked deliveries.
- To test: install the updated rider APK, connect phone and PC to the same LAN,
  allow GPS, and log in with a Nest rider account approved by the admin. Go
  online near the store. The customer places an order; the merchant must mark
  it **Ready for pickup** before dispatch sends a rider offer. New customer
  orders are not offered to riders immediately on placement.
- Existing local test account: `rider_1790708522081@test.com` /
  `Rider@123456`. Its data was not reset. No phone was attached during checks.
  APK: `talaDelivery-rider/build/app/outputs/flutter-apk/app-debug.apk`.
- Verification: 43 rider tests passed (one opt-in live test skipped in the
  normal suite), Flutter analysis clean, 217 backend tests passed, dispatch
  typecheck passed. The opt-in native Flutter live test also passed against
  the LAN API and Socket.IO, including reconnect. Broker probes used an unused
  synthetic user room; no customer orders or persistent test notifications
  were created, and the existing rider's status, deliveries and balance were
  unchanged.

```powershell
# From talaDelivery-rider:
C:\php\flutter\bin\flutter.bat build apk --debug --dart-define-from-file=config/local.json
C:\php\flutter\bin\flutter.bat test
C:\php\flutter\bin\flutter.bat analyze
C:\php\flutter\bin\flutter.bat test test/rider_live_connection_test.dart --dart-define-from-file=config/local.json --dart-define=TALA_RUN_LIVE_RIDER_TEST=true
# From taladelivery-backend:
node test/rider-api-connection.mjs
```

### Rider/customer live maps and navigation (2026-10-06)

- Both apps show rider movement, the pickup store (blue), and the order's saved
  customer delivery pin (green). The rider is orange. The customer is **not**
  continuously GPS-tracked; the rider navigates to the address pin selected at
  checkout. Camera fitting keeps the stops visible alongside the rider.
- The rider map requests actual driving road geometry from Mapbox Directions.
  Requests are limited to once per 30 seconds, except when the destination
  changes. Missing routes are reported without inventing a straight-line route.
  The configured local Mapbox token was verified against Directions.
- Active delivery screen: **Google Maps: pickup** before pickup, then
  **Google Maps: customer** after pickup. iOS also has **Apple Maps**. External
  maps use their own current GPS location as the origin and the saved stop pin
  as the destination. External navigation works independently of embedded maps.
- Continuous Geolocator GPS starts an Android location foreground service with
  a tracking notification and wake lock for an active delivery. iOS declares
  location background mode and usage descriptions; the active stream enables
  background updates and the location indicator. Switching to Maps or locking
  the screen no longer stops an active delivery's GPS stream. Completion,
  cancellation, logout, and idle app backgrounding stop the appropriate stream.
  Foreground availability-only GPS can continue while online after completion.
- Allow precise location and keep Tala running. Phone battery restrictions,
  force-stop/swiping away the app, loss of network/GPS, or revoked permissions
  can interrupt tracking. This is not a force-kill-resistant tracking service.
  Android background-location permission is intentionally not requested: the
  active foreground service is started while the rider app is visible. An
  assignment received while the rider app is already backgrounded starts GPS
  when the rider opens Tala. Use **Location settings** if access was blocked.
- `GET /api/v1/orders/:id` now includes a compact dispatch tracking snapshot
  after checking customer ownership. Realtime uses `delivery:<deliveryId>`;
  order IDs and delivery IDs are not interchangeable. Order/delivery room
  joins verify ownership/assignment/store membership; rider rooms verify the
  dispatch rider ID. Raw socket location writes are refused. GPS must pass
  authenticated `POST /rider/location` ownership and validation checks.
  The location worker sends camelCase Flutter fields and a timestamp, and the
  customer rejects invalid, older, unrelated, and unacknowledged location events.
- Local dispatch, order, and realtime services were individually restarted with
  these changes (ports 3005, 3004, 3008); other services were left running.
- Checks: rider/customer Flutter analysis, 52 rider tests (one opt-in live test
  skipped), 63 customer tests, 226 backend tests, and dispatch/order/realtime
  typechecks. Both debug APKs are rebuilt with their ignored LAN configs.
  The live tracking probe verified the customer snapshot, delivery-room access
  control, socket spoofing rejection, and the location broker event. Its GPS
  event targeted unused synthetic IDs only. No real orders, rider positions,
  coin balances, or persistent notifications were changed.
- Physical phone background/lock-screen testing remains required: no Android or
  iOS device was connected here. iOS must be built/signed and tested on a Mac;
  Apple Maps and background location are configured but not device-verified.
  Use HTTPS/WSS for production API/realtime access.

```powershell
# From taladelivery-backend (read-only API checks; isolated synthetic queue probe):
node test/delivery-tracking-connection.mjs
# From either Flutter app:
C:\php\flutter\bin\flutter.bat analyze
C:\php\flutter\bin\flutter.bat test
C:\php\flutter\bin\flutter.bat build apk --debug --dart-define-from-file=config/local.json
```

Phone acceptance test: install both new APKs on the same LAN as the PC, allow
rider GPS, place a customer order in an assigned store delivery zone, and mark
it Ready for pickup in the merchant app. Accept the rider offer. Open Google
Maps to pickup, move outdoors, and verify the customer's orange marker and
update timestamp change. Confirm pickup in Tala and check navigation switches
to the customer pin. Repeat with the rider screen locked. Complete/cancel the
delivery and verify active background sharing stops. Test equivalent behavior
on iPhone/Apple Maps when a signed iOS build is available.

Navigation references: [Google Maps URLs](https://developers.google.com/maps/documentation/urls/get-started),
[Apple Map Links](https://developer.apple.com/library/archive/featuredarticles/iPhoneURLScheme_Reference/MapLinks/MapLinks.html),
[Mapbox Directions](https://docs.mapbox.com/api/navigation/directions/),
and [Geolocator background setup](https://pub.dev/packages/geolocator).
