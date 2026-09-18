# API update and customer-app connection status

Updated September 18, 2026 against Laravel `feature/tala-api` at `af48be1`
(`Features/add websockets`). The customer Flutter changes below are implemented
locally but have not been committed. Live WebSocket delivery still depends on
the Laravel runtime being configured and running.

## What changed in `tala_delivery_api`

| Backend update | What it does | Customer-app impact |
| --- | --- | --- |
| Laravel Reverb and broadcasting configuration | Adds a WebSocket broadcaster and a Sanctum-protected `broadcasting/auth` route. | Flutter now has an authenticated private-channel client; the backend runtime must still be configured for Reverb. |
| `OrderUpdated` event | Broadcasts order ID, number, status, total, and update time to the customer's private `user.{id}` channel and the store's private `store.{id}` channel. It is dispatched during order creation and status transitions. | Flutter now listens for `order.updated` and re-fetches the order/orders list. |
| `NotificationCreated` event | Broadcasts a new notification to the recipient's private `user.{id}` channel. | Flutter now listens for `notification.created` and refreshes notifications/home unread count. |
| `DeliveryOffered` event | Broadcasts a 30-second offer to a rider's private `user.{id}` channel. | Rider-side feature; it does not go to the customer channel. |
| Demo rider, merchant, orders, and offer tools | Provides local-only seeders and Artisan commands to exercise the full workflow. | Useful for end-to-end testing; no new customer Flutter endpoint is required. |
| Admin store creation | Creating a store now also requires merchant-account details and creates that account. | New active stores can appear in the customer catalog after a REST refresh. |
| Product image support | Store-admin products accept a validated base64 data-URI image up to 5 MB; the database image column is widened. | Customer product rows and details now show supported raster data-URI images with an icon fallback. |
| Paginated response helper and role-guard corrections | Standardizes several paginated API responses and fixes Sanctum role middleware for admin/store-admin routes. | Customer repositories now follow pagination metadata and combine pages, deduplicating IDs. |

Backend sources: [`OrderUpdated`](../tala_delivery_api/app/Events/OrderUpdated.php),
[`NotificationCreated`](../tala_delivery_api/app/Events/NotificationCreated.php),
[`DeliveryOffered`](../tala_delivery_api/app/Events/DeliveryOffered.php),
[`channels.php`](../tala_delivery_api/routes/channels.php), and
[`broadcasting.php`](../tala_delivery_api/config/broadcasting.php).

## What the customer app already connects through REST

| Feature | Current connection |
| --- | --- |
| Authentication | Register, login, `GET /auth/me`, logout, and `PUT /auth/profile`; protected requests send the Sanctum bearer token and `X-App-Key`. The bearer token is now stored with platform-secure storage. |
| Address book | Lists, creates, updates, and deletes saved addresses; address setup is part of the route guard. |
| Catalog | Loads and searches stores/products from Laravel instead of displaying demo stores. |
| Checkout | Sends cart lines, delivery address, and notes to `POST /orders`; Laravel is authoritative for prices, stock, availability, and delivery fees. |
| Orders | Lists, fetches, tracks, and cancels orders through REST. `order.updated` refreshes active views when Reverb is available; tracking still polls every 15 seconds as fallback. |
| Notifications | Fetches notifications through REST and marks them read; `notification.created` refreshes the list and home unread badge when Reverb is available. |
| Appearance | Light, Dark, and System modes are local persisted preferences; they do not need an API endpoint. |

The customer API client is in
[`customer_api_client.dart`](lib/customer/core/network/customer_api_client.dart).
The latest API pagination wrapper is compatible with the existing
[`_payloadList`](lib/customer/shared/models/catalog_models.dart) parser.

## Connection status and remaining gaps

| Status | Area | Current behavior | Remaining work |
| --- | --- | --- | --- |
| Client done; runtime pending | Private WebSocket subscription | [`CustomerRealtimeController`](lib/customer/core/realtime/customer_realtime.dart) authenticates `private-user.{id}` with Sanctum, listens for events, deduplicates, reconnects, and stops on logout. | Configure `TALA_REVERB_WS_URL` and the **public** `TALA_REVERB_APP_KEY`; run Laravel Reverb and queue worker. Without these, REST still works. |
| Client done; runtime pending | Instant order updates | [`OrderTrackingPage`](lib/customer/features/orders/order_screens.dart) and the orders list re-fetch on `order.updated`; polling/manual refresh remain. | Verify an actual backend event reaches a device/emulator. |
| Client done; runtime pending | Instant notifications and unread badge | [`NotificationsPage`](lib/customer/core/notifications/notifications_screen.dart) and [`HomePage`](lib/customer/features/home/home_screen.dart) refresh on `notification.created`. | Verify actual event delivery on a device/emulator. |
| Done for raster images | Product imagery | Rows/details render PNG, JPEG, GIF, and WebP data URIs. Invalid/unsupported data (including SVG) falls back to icon artwork. | Add SVG rendering only if required. |
| Partly done | Pagination | Store, product, order, and notification repositories fetch successive pages and deduplicate IDs instead of stopping at 100. | Add incremental load-more UI if large lists make eager multi-page loading too slow. |
| Done | Durable customer login | `SecureCustomerTokenStore` uses platform-secure storage; login awaits persistence, restore reads it, and logout clears it. | Verify device-specific secure-storage behavior in a native build. |
| Not connected | Password recovery | The Forgot password screen clearly says recovery is unavailable; Laravel has no matching endpoint. | Define a reset/email flow and connect it if required. |
| Not connected | Background/offline alerts | Foreground WebSockets do not deliver alerts after the app is closed. | Choose and configure a push provider if closed-app alerts are required. |

Existing REST flows remain authoritative and are the fallback when Reverb is
not configured, disconnected, or the app is in the background.

## Backend setup still required for real WebSockets

The checked-in [`.env.example`](../tala_delivery_api/.env.example) still sets
`BROADCAST_CONNECTION=log`; that writes broadcast events to the log instead of
delivering them over a WebSocket. A running environment needs Reverb credentials
and host/port/scheme configuration, `BROADCAST_CONNECTION=reverb`, a running
Reverb server, and a queue worker for queued broadcast/matching jobs. Keep the
Reverb app **secret** and Laravel `APP_KEY` out of Git and Flutter. The Reverb
app key is public connection information and can be passed to Flutter. See
[`config/local.example.json`](config/local.example.json) for the Flutter
setting names. An Android emulator needs a reachable host such as
`10.0.2.2` instead of `127.0.0.1` for both the API and socket URLs.

The existing Laravel JavaScript Echo setup is for Laravel's JavaScript client.
It does not automatically connect either Flutter app.

## What was executed and what remains

1. Implemented a customer realtime service and connected it to login, restore,
   logout, app lifecycle, order views, notifications, and the home badge.
2. Added product data-URI rendering, multi-page repository retrieval, secure
   token storage, and removed the source-code API-key fallback.
3. Added Flutter tests for private-channel authorization, duplicate events,
   order and notification UI refresh, image fallback, multi-page retrieval,
   and token-store behavior.
4. Still required: configure and run Reverb/queue in the target environment,
   supply its public Flutter connection settings, and verify end-to-end event
   delivery on a device. Push and password reset need separate product/backend
   decisions.

The Laravel suite passed **48 tests / 273 assertions**. The new customer
integration has Flutter unit/widget coverage but has not been verified with a
live backend event on a device.
