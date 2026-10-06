# Rider Wallet / Tala Coins — Completion Summary

Date: October 6, 2026 (Asia/Manila)

## Scope

Implemented the wallet page in `tala_delivery_rider` using the backend in `tala_delivery_nestjs_api` on `features/nestjs-api`. The Laravel project `tala_delivery_api` was not changed.

The implementation is complete in local source code. The new backend endpoints must be deployed or served locally before an installed Rider app can use them. The initial implementation did not perform a production deployment, database migration, commit, or push. The source changes and this report are now being published to the `rider` and `features/nestjs-api` GitHub branches at the user’s request. Production deployment remains a separate step.

## Existing functionality found

- The Rider application uses Flutter, `ChangeNotifier` controllers, a repository interface, one authenticated HTTP client, named routes, and shared light/dark themes and widgets.
- NestJS already implements Tala Coins in the dispatch service. Rider balances use `numeric(12,2)` and API decimal strings.
- The existing `rider_coin_transactions` ledger records admin top-ups and delivery deductions, signed amounts, balance after, delivery references, notes, and timestamps.
- Admin top-ups are protected by row locking, database transactions, and unique request UUIDs.
- Delivery completion already locks the delivery and rider, deducts the saved delivery-zone percentage of the delivery fee, and commits the balance, ledger entry, and completion together. Delivery IDs have a unique ledger constraint.
- Negative Tala Coins balances are explicitly supported; crossing below zero queues an admin notification with retry handling.
- Rider earnings and commission calculations already exist separately. Earnings are not automatically credited into the Tala Coins ledger under the existing product rules.
- No rider self-service payment-provider top-up, cash-out, pending wallet balance, or peso-to-coin conversion flow was found. The UI does not invent these capabilities.

## Frontend files created

Paths are relative to `tala_delivery_rider`:

- `lib/rider/shared/models/rider_wallet.dart`: wallet/history models and decimal-string coin formatting with grouping and two decimal places.
- `lib/rider/logic/rider_wallet_controller.dart`: independent balance/history loading, safe refresh, error recovery, pagination, duplicate suppression, and disposal handling.
- `lib/rider/features/wallet/rider_wallet_screen.dart`: native themed balance card, negative-balance notice, real transaction history, credit/debit amounts, completed status, date/time, delivery/reference details, balance after, empty/loading/error states, retry, pull-to-refresh, and Load more.
- `test/rider_wallet_test.dart`: eight tests covering formatting, authenticated read-only requests, pagination, independent failures, retry, overlapping refreshes, route protection, light/dark rendering, loading, empty state, and pull-to-refresh.

## Frontend files modified

- `lib/rider/app.dart`: registers the wallet models, controller, and screen in the existing Dart library.
- `lib/rider/core/routing/rider_router.dart`: adds the authenticated `/wallet` route.
- `lib/rider/data/rider_repository.dart`: adds wallet balance and paginated transaction methods using the existing API client and response envelope.
- `lib/rider/features/profile/rider_profile_screen.dart`: adds the **Tala Coins** entry using the shared `MenuTile` component.
- `test/rider_app_test.dart`: updates the fake repository and verifies Profile → Tala Coins → back → Home → delivery-search navigation.
- `test/rider_realtime_test.dart`: updates the fake repository for the extended interface.

The pre-existing untracked `assets/images/talaCoin.png` was preserved without modification.

## Backend files created

Paths are relative to `tala_delivery_nestjs_api`:

- `apps/dispatch-service/src/controllers/rider-wallet.controller.spec.ts`: tests authenticated-user balance resolution, rejection of users without a rider profile, rider-scoped history, pagination limits, and credit/debit serialization. These are controller unit tests; existing repository Jest stubs/mock guards are used, not a live HTTP authentication test.

## Backend files modified

- `apps/dispatch-service/src/controllers/rider.controller.ts`: adds authenticated balance/history reads to the existing controller and service architecture. Identity is derived from the JWT user; no rider ID is accepted from the client. History is bounded to 100 entries per page and omits admin actor IDs.
- `apps/dispatch-service/src/services/rider-coins.service.ts`: reuses the existing ledger and mutation flow; replaces floating-point parsing/calculation with exact decimal parsing and integer/BigInt percentage calculations. Invalid amounts/rates and out-of-range balances are rejected.
- `apps/dispatch-service/src/services/rider-coins.service.spec.ts`: adds rollback, malformed/negative amount, large decimal precision, duplicate delivery deduction, rider-scoped history ordering, and pagination coverage.
- `eslint.config.mjs`: fixes the existing import of the absent `typescript-eslint` umbrella package using the already installed parser/plugin packages and their recommended rules. No dependencies were added or upgraded.

## Database changes / migrations

- No new tables, columns, indexes, or migrations were required or created.
- Reused the existing migration `apps/dispatch-service/src/migrations/1791158400000-AddRiderTalaCoins.ts` and its balance column, ledger, rider-history index, unique delivery ID, and unique top-up UUID.
- No database migrations were executed. Ensure the existing dispatch-service migrations are applied in the environment serving the app.

## Endpoints reused

Existing mechanisms remain authoritative:

- `GET /api/v1/rider/profile`
- `GET /api/v1/rider/earnings-summary`
- `POST /api/v1/rider/deliveries/:delivery/complete`
- Admin history: `GET /api/v1/admin/riders/:rider/coins`
- Admin top-up: `POST /api/v1/admin/riders/:rider/coins/top-up`

The wallet UI uses the new rider read endpoints below. The existing gateway `/api/v1/rider` prefix already forwards them to dispatch; no extra gateway routing was needed.

## Endpoints added

- `GET /api/v1/rider/wallet`
  - Standard success envelope with `data.available_tokens` as a decimal string and `data.unit` set to `Tala Coins`.
- `GET /api/v1/rider/wallet/transactions?page=1&per_page=20`
  - Existing paginated success envelope (`data.data`, `data.meta`, `data.links`).
  - Newest-first existing ledger entries, signed amount, direction, completed status, delivery reference, timestamp, note, and balance after.
  - Uses the authenticated user's rider profile. Invalid pagination values default safely; page size is limited to 100.

Both endpoints reuse `AppKeyGuard` and `JwtAuthGuard`. Neither endpoint mutates balances or creates transactions.

## Wallet calculation behavior

- Balance comes directly from the backend's rider Tala Coins balance; the mobile app does not calculate or mutate it.
- Admin-approved top-ups credit the ledger once per unique request ID.
- Delivery completion debits the saved zone percentage of the backend delivery fee. Percentage multiplication now uses exact integers and rounds to the nearest hundredth of a coin.
- Database transactions and row locks remain in place. Unique ledger delivery IDs protect against duplicate deductions; repeated completion attempts cannot debit again. Existing completion error semantics are preserved.
- Existing negative-balance rules remain intact.
- Financial values retain decimal-string precision for storage, API responses, and mobile display. The page displays coins rather than an invented peso conversion.
- Earnings remain in the existing earnings/history flow. No second wallet or earnings-credit scheme was introduced.

## Tests / build commands executed

### NestJS backend

Working directory: `tala_delivery_nestjs_api`.

- `npm ci`: succeeded; installed existing locked dependencies. npm reported 34 dependency vulnerabilities (5 moderate, 29 high); dependencies were not changed as part of this feature.
- `npm run typecheck:dispatch`: passed.
- `npm test -- --runInBand rider-wallet rider-coins delivery.service rider-commission`: passed, **67 tests across 5 suites**.
- `npm run build:dispatch`: passed.
- `npx eslint apps/dispatch-service/src/controllers/rider.controller.ts apps/dispatch-service/src/controllers/rider-wallet.controller.spec.ts apps/dispatch-service/src/services/rider-coins.service.ts apps/dispatch-service/src/services/rider-coins.service.spec.ts`: passed after fixing the existing ESLint configuration import.
- Prettier write/check on the four changed backend TypeScript files and the ESLint config: passed.
- `git diff --check`: passed.

Coverage includes server-configured delivery deductions and commissions, top-up idempotency, invalid amounts, rollback on ledger failure, decimal precision, unique delivery retry protection, authenticated-user scoping, ordering, and bounded pagination.

### Rider application

Working directory: `tala_delivery_rider`.

- Dart formatting of changed/new files: passed.
- `flutter analyze`: passed with no issues after fixing a test formatting lint.
- `flutter test`: passed, **60 tests**, with **1 opt-in live connection test skipped**.
- Final rerun `flutter test test/rider_app_test.dart test/rider_wallet_test.dart`: passed, **9 tests**, including the added Profile navigation check.
- `flutter build web`: passed, output in `build/web`. Flutter reported an existing dependency WebAssembly dry-run warning in `socket_io_common`; the JavaScript web build succeeded.
- `flutter build apk --debug`: blocked because no Android SDK is installed/configured.
- `flutter build bundle`: also blocked by the missing Android SDK.
- `git diff --check`: passed.

Initial test/tool failures were corrected where they concerned this implementation: repository Jest auth mocks/types, test navigation waits for the existing continuously animated UI, and the pre-existing ESLint configuration import. Android packaging remains an environment limitation.

## Remaining limitations / TODOs

1. Deploy the updated NestJS dispatch service, or point the Rider app at a locally running updated gateway. The app still uses its existing public backend URL by default; this task did not deploy those servers.
2. Confirm existing dispatch-service migrations have been applied in the target database. No live database instance or credentials were configured in this new backend checkout, so database integration tests and live authenticated wallet calls were not run. Transaction/rollback tests use the repository's existing unit-test harness.
3. Install/configure the Android SDK and rerun the Android build before distributing an APK. The successful web build does not validate native device plugins or Android packaging.
4. Run the opt-in live Rider test and device QA against the updated backend with a real rider account. No live financial mutations were performed.
5. Top-ups remain admin-managed; cash-out and pending balance are not supported by the current ledger/product flow. No fake payment actions were added.
6. Review existing backend dependency audit findings separately; no audit fix or dependency upgrade was applied.

## How to open the page

Sign in as a rider, open **Profile**, and tap **Tala Coins**. Pull down to refresh balance/history; tap **Load more** for older activity. Arrange top-ups with the platform administrator through the existing admin flow.

## Follow-up: wallet visibility and coin artwork

- Added a coin-image shortcut at the top of the Home screen, beside Notifications. Its tooltip/accessibility label is **Tala Coins wallet**; it opens the existing authenticated wallet route.
- Kept the Profile entry and added the same artwork there and to the wallet balance card.
- Registered the existing `assets/images/talaCoin.png` in `pubspec.yaml`. The actual filename is singular (`talaCoin.png`); no `talaCoins.png` was found. The image itself was not edited.
- Added the reusable `RiderCoinImage` widget and an optional custom leading widget to the existing `MenuTile`.
- Additional frontend files changed: `lib/rider/features/dashboard/rider_dashboard_screen.dart`, `lib/rider/shared/widgets/rider_widgets.dart`, and `pubspec.yaml`; updated the profile, wallet screen, and app navigation test.
- Verification: `flutter analyze` passed with no issues; `flutter test test/rider_app_test.dart test/rider_wallet_test.dart` passed all 9 tests, including Home shortcut navigation and asset loading; `git diff --check` passed.
- Rebuild the installed phone app to include the new code and asset. From `tala_delivery_rider`, run:

```bash
flutter run --release -d 00008140-001E39C6222B001C --device-timeout 60 --dart-define-from-file=config/local.json
```

- The backend deployment requirement above still applies if balance/history calls fail after opening the page.

## Follow-up: dashboard performance metrics

- NestJS now returns `acceptance_rate` in the existing rider profile response, calculated as accepted offers divided by accepted plus rejected offers, multiplied by 100 and rounded to two decimals. Queries are scoped to the rider. Pending/expired offers are excluded because platform-withdrawn offers are not distinguishable from missed offers.
- No answered offers returns null; the Rider dashboard displays N/A rather than a fabricated percentage.
- The profile is refreshed after rejecting an offer so the dashboard receives the authoritative updated rate. Existing acceptance, delivery, and refresh flows already reload profile data.
- On-time calculation is skipped at the user’s request; the gauge is hidden while its backend value is unavailable. No deadline rule or schema was invented.
- Added backend stats and serialization tests, a frontend rejection-refresh test, and assertions covering unavailable metrics.
- Verification: 23 backend tests across stats, matching, and wallet suites passed; dispatch typecheck, build, and lint passed. Flutter analysis passed; 14 relevant app/model/realtime tests passed; the Rider web build passed with the same existing dependency Wasm dry-run warning.
- No new migration is required. Deploy the updated dispatch service and rebuild the Rider app to use these changes.
