# TalaDelivery route guards

This document summarizes the Flutter navigation routes and guards for the
customer and rider applications. The customer guard is now populated by the
Laravel authentication and address APIs. The rider guard still uses an
in-memory session while its API integration is pending.

## Guard priority

Both applications resolve navigation in this order:

1. Unknown route detection.
2. Session restoration/loading.
3. Authentication.
4. Application role.
5. App-specific setup or workflow state.
6. Requested destination.

Flutter guards control navigation and user experience only. Laravel remains
responsible for enforcing token authentication, roles, resource ownership, and
workflow authorization.

## Customer application

Router implementation:
`tala_delivery_customer/lib/customer/core/routing/customer_router.dart`

| Route | Access | Guard behavior |
| --- | --- | --- |
| `/` | Public | Displays the splash screen while the session is restored. |
| `/auth/login` | Public-only | Authenticated customers are sent to setup or home. |
| `/auth/register` | Public-only | Authenticated customers are sent to setup or home. |
| `/auth/forgot-password` | Public-only | Authenticated customers are sent to setup or home. |
| `/address/setup` | Authenticated customer | Unauthenticated users are sent to login; also used for adding and editing addresses. |
| `/home` | Authenticated customer with address | Missing setup redirects to address setup. |
| `/stores` | Authenticated customer with address | Accepts an optional category index argument. |
| `/stores/details` | Authenticated customer with address | Requires a `StoreData` argument. |
| `/products/details` | Authenticated customer with address | Requires a `ProductData` argument and can return a quantity. |
| `/cart` | Authenticated customer with address | Opens the current cart. |
| `/checkout` | Authenticated customer with address | Requires the cart subtotal argument. |
| `/orders` | Authenticated customer with address | Opens the Orders shell tab. |
| `/orders/success` | Authenticated customer with address | Accepts the completed order total. |
| `/orders/tracking` | Authenticated customer with address | Accepts an optional `OrderStage`. |
| `/addresses` | Authenticated customer with address | Lists saved addresses. |
| `/notifications` | Authenticated customer with address | Lists customer notifications. |
| `/profile` | Authenticated customer with address | Opens the Profile shell tab. |
| `/access-denied` | Public fallback | Shown when the restored account is not a customer. |
| `/not-found` | Public fallback | Shown for unknown route names. |

Customer session state:

- `isRestoring`
- `isAuthenticated`
- `role`
- `hasDeliveryAddress`
- pending destination for post-login/setup navigation

## Rider application

Router implementation:
`tala_delivery_rider/lib/rider/core/routing/rider_router.dart`

| Route | Access | Guard behavior |
| --- | --- | --- |
| `/` | Public | Displays the splash screen while the session is restored. |
| `/auth/login` | Public-only | Authenticated riders are sent to the dashboard. |
| `/dashboard` | Authenticated rider | Wrong roles are sent to access denied. |
| `/offers/current` | Authenticated online rider | Offline riders are returned to the dashboard. |
| `/deliveries/active` | Rider with active delivery | Riders without an assigned delivery return to the dashboard. |
| `/deliveries/complete` | Rider with completed delivery | An active delivery returns to its active screen; otherwise the dashboard opens. |
| `/history` | Authenticated rider | Opens the History shell tab. |
| `/profile` | Authenticated rider | Opens the Profile shell tab. |
| `/access-denied` | Public fallback | Shown when the restored account is not a rider. |
| `/not-found` | Public fallback | Shown for unknown route names. |

Rider session state:

- `isRestoring`
- `isAuthenticated`
- `role`
- `isOnline`
- `hasActiveDelivery`
- `deliveryCompleted`
- pending destination for post-login navigation

## Laravel API integration

The customer application now:

1. Registers and logs in through `POST /api/v1/auth/register` and
   `POST /api/v1/auth/login`.
2. Sends the configured `X-App-Key` on every request.
3. Sends the returned Sanctum token as a bearer token on protected requests.
4. Restores an available session through `GET /api/v1/auth/me`.
5. Uses the authenticated user name and phone to prefill address onboarding.
6. Lists, creates, updates, defaults, and deletes saved addresses through the
   `/api/v1/addresses` endpoints.
7. Loads active stores and products through `/api/v1/stores` and
   `/api/v1/products`; empty backend data produces an empty state rather than
   sample shops.
8. Keeps the selected cart locally, then creates and validates the real order
   through `POST /api/v1/orders`.
9. Loads, tracks, refreshes, and cancels customer orders through
   `/api/v1/orders`.
10. Loads notifications and marks individual notifications as read through
    `/api/v1/notifications`.
11. Displays the authenticated Laravel user in the customer home and profile.
12. Calls `POST /api/v1/auth/logout` and clears the local token and cart.

Delivery fees, product prices, availability, and stock are treated as
server-authoritative during order creation. The cart itself remains local UI
state until the customer places the order.

The token store is currently in memory, so users sign in again after a full app
restart. A secure persistent token store can replace it without changing the
screens or repositories.

For local development, copy `config/local.example.json` to
`config/local.json`, set `TALA_API_KEY` to Laravel's `APP_API_KEY`, and select
the **TalaDelivery Customer (local API)** IDE launch configuration. The local
file is ignored by Git so the key is not committed.

The equivalent terminal command is:

```sh
flutter run \
  --dart-define-from-file=config/local.json
```

Use `http://10.0.2.2:8000/api/v1/` for an Android emulator, or the development
computer's LAN address for a physical device. The API key is the Laravel
`APP_API_KEY` value and is not committed to the Flutter repository.

The backend is maintained on `feature/tala-api`. Its customer and rider API
groups should continue to enforce authorization regardless of the Flutter
route result.

## Tests

- Customer flow: `tala_delivery_customer/test/customer_app_test.dart`
- Customer guards: `tala_delivery_customer/test/customer_route_guard_test.dart`
- Customer input validation: `tala_delivery_customer/test/customer_input_validation_test.dart`
- Customer API mapping: `tala_delivery_customer/test/customer_api_test.dart`
- Rider flow: `tala_delivery_rider/test/rider_app_test.dart`
- Rider guards: `tala_delivery_rider/test/rider_route_guard_test.dart`
