# Rider app: connected features, gaps, and AI execution plan

Audited September 18, 2026 against the rider `rider` branch at `7a52535`
and Laravel `feature/tala-api` at `af48be1` (`Features/add websockets`).
This is an implementation plan, not a claim that WebSockets or live location
already work in Flutter.

**Implementation update, September 18:** The work below was subsequently
implemented in the local rider/API worktrees: rider WebSocket subscriptions,
offer reconciliation/polling, consent-aware location reporting, notifications,
delivery pagination, secure token storage, and a rider-scoped API
`delivery.updated` event with matching that skips missing coordinates. The
tables and numbered steps below are retained as the original audit, not the
current implementation status. See [summary.md](summary.md) for the latest
status. Live Reverb delivery and native location permissions still need
device/environment verification.

## What is done and connected

| Rider feature | Current implementation |
| --- | --- |
| Login and session | `POST /api/v1/auth/login` authenticates a rider, rejects a non-rider account, stores the Sanctum token locally, and restores it with `GET /api/v1/auth/me`. Requests include `X-App-Key`; protected calls include the bearer token. |
| Route guards | Login, dashboard, offer, active-delivery, history, and profile routes check authentication and the relevant online/delivery state. The backend still enforces ownership and valid state transitions. |
| Profile and approval | `GET /api/v1/rider/profile` loads account, approval, vehicle, availability, and current-delivery data. Pending, rejected, and suspended riders cannot go online. |
| Availability | The dashboard calls `POST /api/v1/rider/online` and `/offline`. Going online also fetches pending offers. |
| Offers | `GET /api/v1/rider/offers` loads eligible, unexpired offers on session load, manual refresh, and the transition online. Accept/reject uses the protected offer endpoints. The offer screen counts down from the server's expiry time. |
| Delivery workflow | Assigned deliveries come from `GET /api/v1/rider/deliveries`; arrived, pickup, start, and complete buttons call Laravel transitions. COD completion has a local cash-confirmation checkbox. |
| Dashboard and history | Counts and earnings are calculated from API delivery records, not hard-coded fixtures. Loading, empty, and error states exist. |
| Appearance | Light, Dark, and System modes are persisted locally; no API connection is needed. |

The main implementation is in [`RiderAppController`](lib/rider/logic/rider_app_controller.dart),
[`ApiRiderRepository`](lib/rider/data/rider_repository.dart), and
[`RiderApiClient`](lib/rider/core/network/rider_api_client.dart).

## What is not connected or is incomplete

| Priority | Gap | Evidence and user impact | Needed connection |
| --- | --- | --- | --- |
| High | Instant delivery offers | Laravel emits [`DeliveryOffered`](../tala_delivery_api/app/Events/DeliveryOffered.php) as `delivery.offered` on the rider's private `user.{userId}` channel. Flutter has no WebSocket client, channel authentication, or listener. The offer screen's one-second timer only updates an offer **after** REST has loaded it; it does not discover new offers. A 30-second offer can expire before the rider manually refreshes. | Subscribe after login; when online and eligible, respond to an event by fetching authoritative `GET /api/v1/rider/offers` and updating dashboard/offer UI. Reconnect and resync on app resume. |
| High | Rider location for matching | Laravel exposes `POST /api/v1/rider/location` and matching compares the pickup coordinates with each eligible rider's stored coordinates. Flutter does not call that endpoint or request location permission. | With rider consent, obtain location and post `{latitude, longitude}` when starting/continuing a shift and at a deliberate, battery-aware interval. Handle denied/unavailable permission. The backend should exclude riders without usable coordinates rather than treating missing coordinates as `(0, 0)`. |
| High | Offer and active-delivery freshness | The app fetches offers/profile/deliveries during login and manual refresh, but it does not continuously reconcile expired offers or externally assigned/cancelled deliveries. The offer page can retain a stale route-argument offer; its progress ring uses 120 seconds although backend offers expire after 30. The backend does not broadcast a rider-facing delivery-changed event today. | Refresh on socket reconnect, app resume, and offer expiry; reconcile the displayed offer with controller data and derive countdown/progress from the actual offer window. Add a bounded fallback poll while online. If instant external assignment/cancellation is required, add a rider-scoped backend event and handle it in Flutter. Keep accept/complete failures authoritative. |
| Medium | Rider notifications | Laravel provides `GET /api/v1/notifications`, `POST /api/v1/notifications/{id}/read`, and [`notification.created`](../tala_delivery_api/app/Events/NotificationCreated.php) on the same private user channel. The rider app has no notifications repository or screen. | Add rider notification models/repository/UI and a badge, then refresh on the event. Avoid duplicate entries on reconnect. |
| Medium | Complete history and earnings | `GET /api/v1/rider/deliveries?per_page=100` loads only the first page; pagination metadata is discarded. Client-calculated period totals may be incomplete above 100 deliveries. | Load further pages or provide server-calculated totals; test page merging and filters. |
| Medium | Token storage | Production uses `SharedPreferences`, which persists a session but is not platform-secure secret storage. | Move the bearer token to secure platform storage; preserve restore/logout/expiry behavior. |
| Later | Rider registration | Laravel has `POST /api/v1/rider/register` with an approval workflow, but the Flutter app has no registration screen. A pending rider can sign in but cannot go online. | If self-application is a product requirement, add a validated registration/application screen and pending-approval state. Otherwise document that accounts are created outside the app. |
| Later | Navigation and background alerts | Pickup/drop-off addresses are shown as text, not turn-by-turn navigation. A foreground WebSocket will not alert a rider when the app is closed. | Add map/deep-link navigation only if required; use a separate push-notification service for background/terminated alerts. |
| Later | COD audit trail | The cash-received checkbox is UI-only; `POST /complete` sends no cash-receipt evidence. Laravel marks the order paid on completion. | If auditable cash collection is required, define and validate a server-side confirmation field/workflow before changing the app. |

These gaps do **not** mean the existing REST offer or delivery workflow is
static. They distinguish working API calls from live updates and additional
product features.

## Backend requirements for realtime

The API now includes Reverb support, private channel authorization in
[`routes/channels.php`](../tala_delivery_api/routes/channels.php), and
`GET|POST /broadcasting/auth` protected by Sanctum. That authorization route
is **outside** `/api/v1`; the `X-App-Key` middleware is attached to API routes,
while broadcast authorization needs the rider's bearer token. The
`delivery.offered` event contains an offer ID and partial delivery details, not
the complete REST offer model, so Flutter should refetch the offer list.

The checked-in [`.env.example`](../tala_delivery_api/.env.example) still uses
`BROADCAST_CONNECTION=log`. To actually deliver events, an environment must
configure the Reverb app ID/key/secret and reachable host/port/scheme, switch
to `BROADCAST_CONNECTION=reverb`, and run Reverb plus the queue worker. The
Flutter app needs the **public** Reverb app key and reachable socket endpoint;
the Reverb app **secret** and Laravel `APP_KEY` must never be embedded in Flutter
or committed. The existing Laravel JavaScript Echo file does not connect the
Flutter app.

## How an AI agent should execute the remaining work

Work in small, testable changes. Recheck the backend event contract and the
current rider code before editing; keep each app's changes on its own branch.

1. **Establish a working backend fixture.** On `feature/tala-api`, confirm the
   API, database, queue worker, and Reverb server are running with non-secret
   public connection settings available to the rider app. Use the local-only
   demo rider/order/offer helpers or an approved test account. Verify that
   `/broadcasting/auth` authorizes that rider's `user.{id}` channel and rejects
   another user's channel. Do not place credentials in the repository.
2. **Build a rider realtime service.** On `rider`, add a compatible Flutter
   WebSocket/Pusher-protocol client, injectable socket URL/public app key, and a
   small service owned by [`RiderAppDependencies`](lib/rider/core/di/rider_dependencies.dart).
   Authenticate private subscription with the Sanctum token, subscribe to
   `user.{userId}` after login/restore, reconnect after network/app-lifecycle
   changes, and unsubscribe/dispose on logout. Do not expose the bearer token
   in logs. Unit-test auth, reconnect, and cleanup with fakes.
3. **Connect offers safely.** Listen for `delivery.offered`; refetch
   `GET /api/v1/rider/offers` instead of trusting the partial event payload.
   Deduplicate by offer ID, ignore already-expired offers, show the offer in
   dashboard/offer UI, and provide an obvious prompt while the app is open.
   Reconcile on resume/reconnect and use a short, lifecycle-aware REST poll
   while online as a fallback. Stop the poll when offline, busy, or logged out.
   Keep the backend's 422 response decisive when an offer expires or is taken.
4. **Connect location intentionally.** Add an injectable location source,
   permission handling, and `POST /api/v1/rider/location` to
   [`ApiRiderRepository`](lib/rider/data/rider_repository.dart). Send coordinates
   only with rider consent and a clear online-shift policy; avoid unnecessary
   background tracking. Add tests for granted, denied, unavailable, and stale
   locations. On the API branch, make matching skip missing/invalid rider
   coordinates and test nearest-rider selection.
5. **Add notification and state reconciliation.** Add rider notification REST
   models/UI if in scope, handling `notification.created` via refetch. Refresh
   profile, offers, and deliveries on app resume, after mutations, and after
   reconnect. If admin assignment/cancellation must appear instantly, first
   define a backend `delivery.updated` event restricted to the affected rider,
   test authorization/payload, then consume it in Flutter. Do not assume
   `order.updated` reaches riders: it currently targets customer/store.
6. **Finish lower-priority gaps.** Add delivery pagination or server totals,
   secure token storage, and optional self-registration/navigation/push only
   after their product requirements and external services are decided.

**Acceptance checks:** a new store-ready order reaches an online rider without
manual refresh; the offer countdown uses the server expiry; accept/reject and
expiry remain correct during reconnect; logout removes subscriptions; a rider
cannot subscribe to someone else's channel; location permission failure does
not crash the app; and external changes are reconciled after resume. Run
`flutter analyze` and `flutter test` for rider changes, plus `php artisan test`
for backend changes. Test the full offer flow on a device/emulator with a
reachable API and socket host; unit tests alone do not prove WebSocket delivery.

The original audit changed documentation only. The later implementation is
summarized at the top of this file and in `summary.md`.
