# TalaDelivery route guards

This document summarizes the Flutter navigation routes and guards for the
customer and rider applications. The guards currently use in-memory session
objects so the navigation behavior can be developed and tested without a
database. They are ready to be connected to the Laravel API authentication
response later.

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

When the API environment is available, the in-memory session objects should be
populated through an authentication repository:

1. Send credentials to `POST /api/v1/auth/login` with `X-App-Key`.
2. Securely store the returned Sanctum bearer token.
3. Restore the session with `GET /api/v1/auth/me`.
4. Map the returned `user.role` to the Flutter role state.
5. Map customer addresses and rider status to the app-specific guard state.
6. Clear the local session on logout or any API `401` response.

The backend is maintained on `feature/tala-api`. Its customer and rider API
groups should continue to enforce authorization regardless of the Flutter
route result.

## Tests

- Customer flow: `tala_delivery_customer/test/customer_app_test.dart`
- Customer guards: `tala_delivery_customer/test/customer_route_guard_test.dart`
- Rider flow: `tala_delivery_rider/test/rider_app_test.dart`
- Rider guards: `tala_delivery_rider/test/rider_route_guard_test.dart`
