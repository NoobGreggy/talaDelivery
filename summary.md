# TalaDelivery development summary

Last updated: September 16, 2026

## Repository layout and branches

The project is split into three local repositories that point to
`https://github.com/NoobGreggy/talaDelivery.git`:

| Application | Local folder | Git branch | Latest pushed commit |
| --- | --- | --- | --- |
| Customer Flutter app | `tala_delivery_customer` | `customer` | `56a20f6` |
| Rider Flutter app | `tala_delivery_rider` | `rider` | `a288331` |
| Laravel API | `tala_delivery_api` | `feature/tala-api` | `3c9f00d` |

Git commits use `yazzumi <horiuchiryuta@gmail.com>`.

## Customer application

The customer Flutter application now uses the Laravel API instead of static
catalog, account, address, order, and notification data.

Completed functionality:

- Registration, login, logout, and session restoration through Laravel
  Sanctum.
- `X-App-Key` is included on every API request.
- Authenticated requests include the Sanctum bearer token.
- Login and registration forms use client-side and Laravel field validation.
  Required-field messages do not appear until the first submit attempt.
- New customers must create a delivery address before entering protected
  shopping routes.
- Customers with an existing saved address skip address setup after login.
- Address setup is prefilled with the registered customer name and phone.
- Saved addresses can be listed, created, updated, set as default, and deleted.
- Stores and products are loaded from Laravel, including searchable store
  listings and honest loading, empty, and error states.
- The cart remains local until checkout; order prices, stock, availability, and
  delivery fees are validated by Laravel when the order is placed.
- Customers can place, list, track, refresh, and cancel API-backed orders.
- Notifications are loaded from Laravel and can be marked as read.
- Profile data comes from the authenticated Laravel user.
- The Profile screen includes an Edit profile button. Customers can update
  their name, email, and optional phone number. The active session and visible
  Profile card refresh immediately after a successful save.
- Light, Dark, and System appearance modes are available and persisted.

### Customer routes and guards

| Route | Required state |
| --- | --- |
| `/` | Public session-restoration screen |
| `/auth/login` | Public-only |
| `/auth/register` | Public-only |
| `/auth/forgot-password` | Public-only |
| `/address/setup` | Authenticated customer |
| `/home` | Authenticated customer with a saved address |
| `/stores` | Authenticated customer with a saved address |
| `/stores/details` | Authenticated customer with a valid `StoreData` argument |
| `/products/details` | Authenticated customer with a valid `ProductData` argument |
| `/cart` | Authenticated customer with a saved address |
| `/checkout` | Authenticated customer with a saved address |
| `/orders` | Authenticated customer with a saved address |
| `/orders/success` | Authenticated customer with a valid `CustomerOrder` argument |
| `/orders/tracking` | Authenticated customer with an order or order ID |
| `/addresses` | Authenticated customer with a saved address |
| `/notifications` | Authenticated customer with a saved address |
| `/profile` | Authenticated customer with a saved address |
| `/profile/edit` | Authenticated customer with a saved address |
| `/access-denied` | Public fallback for the wrong application role |
| `/not-found` | Public fallback for unknown routes |

Customer guard order:

1. Reject unknown routes.
2. Wait for session restoration.
3. Require authentication.
4. Require the customer role.
5. Require address setup for shopping and account routes.
6. Restore the originally requested route after login/setup.

## Rider application

The rider Flutter application now uses the Laravel rider workflow instead of
the former static rider, earnings, offer, and delivery fixtures.

Completed functionality:

- Rider login uses the shared Laravel authentication endpoint and rejects
  accounts that do not have the rider role.
- Rider tokens are persisted locally and restored when the app starts.
- The rider profile, approval status, vehicle details, availability, delivery
  totals, and history are loaded from the API.
- Going online or offline calls the Laravel rider availability endpoints.
- Pending, rejected, and suspended riders cannot go online.
- Live delivery offers are loaded from Laravel with server-provided expiry,
  distance, store, customer, payment, and delivery-fee data.
- Offer acceptance and rejection call the corresponding protected API routes.
- Active deliveries use backend state and call the arrived, pickup, start, and
  complete transitions in the required order.
- Cash-on-delivery confirmation is required in the UI before completing a COD
  delivery.
- Dashboard and history totals are calculated from API deliveries rather than
  demonstration records.
- Loading, retry, empty, expired-offer, and server-error states replace static
  placeholder content.
- Light, Dark, and System appearance modes are available and persisted.
- Android and macOS network permissions are configured.

### Rider routes and guards

| Route | Required state |
| --- | --- |
| `/` | Public session-restoration screen |
| `/auth/login` | Public-only |
| `/dashboard` | Authenticated rider |
| `/offers/current` | Authenticated online rider |
| `/deliveries/active` | Rider with an active delivery |
| `/deliveries/complete` | Rider that just completed a delivery |
| `/history` | Authenticated rider |
| `/profile` | Authenticated rider |
| `/access-denied` | Public fallback for the wrong application role |
| `/not-found` | Public fallback for unknown routes |

Rider guard state is synchronized with the API-backed rider controller,
including authentication, role, online status, active delivery, completion,
and a pending destination.

## Laravel API

The Laravel backend provides the shared source of truth for both applications.

Relevant completed functionality:

- App-key middleware validates `X-App-Key`.
- Sanctum issues and validates bearer tokens.
- Customer registration, login, current-user, logout, and authenticated profile
  update endpoints are available.
- Profile updates validate name, email, and phone; email uniqueness ignores the
  current user but rejects addresses belonging to another account.
- Customer address ownership and CRUD operations are enforced.
- Store/product browsing and search use database records.
- Customer order creation, history, tracking, and cancellation are implemented.
- Store-admin order transitions confirm, prepare, and mark orders ready.
- Rider registration, approval state, availability, profile, location,
  deliveries, offers, and delivery status transitions are implemented.
- Rider matching selects an eligible online rider and creates a 30-second
  delivery offer after the store marks an order ready.
- Demo customer stores and products can be inserted with the development
  seeder for local testing.

Important API endpoints:

| Method and endpoint | Purpose |
| --- | --- |
| `POST /api/v1/auth/register` | Register a customer |
| `POST /api/v1/auth/login` | Log in any supported role |
| `GET /api/v1/auth/me` | Restore the authenticated user |
| `PUT /api/v1/auth/profile` | Update the authenticated user's details |
| `POST /api/v1/auth/logout` | Revoke the current token |
| `GET/POST/PUT/DELETE /api/v1/addresses` | Manage customer addresses |
| `GET /api/v1/stores` | Browse and search active stores |
| `GET /api/v1/products` | Browse products |
| `GET/POST /api/v1/orders` | List and create customer orders |
| `POST /api/v1/orders/{order}/cancel` | Cancel an eligible customer order |
| `GET /api/v1/notifications` | List authenticated notifications |
| `GET /api/v1/rider/profile` | Load rider status and details |
| `POST /api/v1/rider/online` | Set an approved rider online |
| `POST /api/v1/rider/offline` | Set a non-busy rider offline |
| `GET /api/v1/rider/offers` | Load pending rider offers |
| `POST /api/v1/rider/offers/{offer}/accept` | Accept an offer |
| `POST /api/v1/rider/offers/{offer}/reject` | Reject an offer |
| `GET /api/v1/rider/deliveries` | Load rider deliveries/history |
| `POST /api/v1/rider/deliveries/{delivery}/{action}` | Run `arrived`, `pickup`, `start`, or `complete` |

Flutter guards improve navigation and user experience. Laravel remains
responsible for authoritative authentication, roles, ownership, validation,
prices, stock, and workflow transitions.

## Local API configuration

Both Flutter projects contain `config/local.example.json`. Create the ignored
`config/local.json` with:

```json
{
  "TALA_API_BASE_URL": "http://127.0.0.1:8000/api/v1/",
  "TALA_API_KEY": "the same value as Laravel APP_API_KEY"
}
```

Do not commit `config/local.json` or the real API key.

Run either Flutter application with:

```sh
flutter run --dart-define-from-file=config/local.json
```

Use `http://10.0.2.2:8000/api/v1/` from an Android emulator. A physical device
must use the development computer's reachable LAN address instead of
`127.0.0.1`.

## Order-to-rider flow

1. The customer submits an order.
2. The store administrator confirms and prepares the order.
3. The store marks it ready for pickup.
4. Laravel dispatches the queued `MatchRider` job.
5. The matching service selects an eligible approved rider who is online.
6. Laravel creates a 30-second offer for that rider.
7. The rider accepts or rejects the offer.
8. An accepted delivery progresses through arrived, picked up, in transit, and
   delivered states.

A Laravel queue worker must be running when the configured queue connection is
asynchronous.

## Realtime status and remaining work

Delivery offers are not currently true realtime pop-ups. The backend stores
offers and exposes them through `GET /api/v1/rider/offers`, while the rider app
loads them during login, refresh, and the transition to online.

Two possible next steps:

1. Add app-lifecycle-aware polling every 3–5 seconds while the rider is online.
   This works with the existing REST API.
2. Add Laravel Reverb, Pusher, or Ably. The backend must broadcast a new-offer
   event on a private rider channel and provide the WebSocket host, port,
   scheme, app key, channel authentication endpoint, and queue configuration.

Other known limitations:

- The customer token store is currently memory-based, so a full app restart
  requires customer login again.
- The rider token is persisted with shared preferences. Production deployments
  should use platform-secure token storage.
- Android packaging was not run locally because the Android SDK is not
  configured on the development machine. Flutter analysis, tests, and the rider
  web build succeeded.

## Verification status

At the latest pushed commits:

- Customer Flutter: `flutter analyze` passed and 21 tests passed.
- Rider Flutter: `flutter analyze` passed and 9 tests passed.
- Laravel API: formatting passed and 38 tests passed with 235 assertions.
- Rider web compilation succeeded with the local API configuration.

Primary test files:

- `test/customer_app_test.dart`
- `test/customer_api_test.dart`
- `test/customer_input_validation_test.dart`
- `test/customer_profile_test.dart`
- `test/customer_route_guard_test.dart`
- `test/customer_store_search_test.dart`
- `test/customer_theme_test.dart`
- `test/rider_app_test.dart`
- `test/rider_api_client_test.dart`
- `test/rider_models_test.dart`
- `test/rider_route_guard_test.dart`
- `test/rider_theme_test.dart`
- `tests/Feature/AuthTest.php`
- `tests/Feature/RiderFlowTest.php`

## Git and security notes

- Customer changes belong on `customer`.
- Rider changes belong on `rider`.
- Backend changes belong on `feature/tala-api`.
- No application should be developed directly on `main`.
- Local `.env` files, `config/local.json`, API keys, and Sanctum tokens must not
  be committed.
