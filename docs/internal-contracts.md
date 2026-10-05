# TalaDelivery Internal Contracts

Version: 1.0 — Locked at Phase 1-11 implementation. Do not change without updating every service.

All internal HTTP routes:
- are served on the **service's own port** (internal, not through the gateway);
- require the `X-Service-Token: <INTERNAL_API_TOKEN>` header (use `ServiceAuthGuard`);
- return the standard envelope `{ success, message, data }` (global interceptor adds it).
- `ServiceClient.*` (from `@taladelivery/common`) unwraps `data` automatically. It throws
  `ServiceCallError` (`status`, `body`, `code`) for non-2xx responses.

Money is always transferred as **decimal strings** (e.g. `"200.00"`). Never floats.

## 1. Cross-service HTTP endpoints

### 1.1 identity-service (DB: taladelivery_identity)

| Method | Path | Auth | Request body | Response `data` |
| --- | --- | --- | --- | --- |
| POST | `/internal/users` | service | `{ name, email, phone?, password, role, status }` | `UserSnapshot` |
| GET | `/internal/users/:id` | service | – | `UserSnapshot` |
| GET | `/internal/users/by-email/:email` | service | – | `UserSnapshot \| null` |
| GET | `/internal/users/batch?ids=1,2,3` | service | – | `UserSnapshot[]` |
| GET | `/internal/admin/totals` | service | – | `{ customers: number }` |

`UserSnapshot` = `{ id, name, email, phone: string|null, role, status }`.

### 1.2 merchant-service (DB: taladelivery_merchant)

| Method | Path | Auth | Request body | Response `data` |
| --- | --- | --- | --- | --- |
| GET | `/internal/stores/:id` | service | – | `StoreSnapshot` |
| GET | `/internal/stores/batch?ids=1,2` | service | – | `StoreSnapshot[]` |
| POST | `/internal/store-users` | service | `{ storeId, userId }` | `{ id, storeId, userId }` |
| POST | `/internal/store-users/verify` | service | `{ storeId, userId }` | `{ userId, storeId }` or 403 |
| GET | `/internal/stores/:id/store-users` | service | – | `{ userIds: number[] }` |
| POST | `/internal/stores` | service | `{ name, slug?, ... store fields }` | `StoreSnapshot` |
| GET | `/internal/admin/totals` | service | – | `{ stores: number }` |

`StoreSnapshot` = `{ id, name, slug, status, latitude: string|null, longitude: string|null, address: string|null, phone: string|null }` (already in `libs/contracts`).

### 1.3 catalog-service (DB: taladelivery_catalog)

| Method | Path | Auth | Request body | Response `data` |
| --- | --- | --- | --- | --- |
| POST | `/internal/orders/validate` | service | see below | see below |
| GET | `/internal/admin/totals` | service | – | `{ products: number, categories: number }` |

`POST /internal/orders/validate` request:

```json
{
  "storeId": 1,
  "items": [ { "productId": 42, "quantity": 2 } ]
}
```

Behavior (mirrors Laravel `OrderService::create` item loop):
1. Store snapshot + product must belong to store. If product not found → 404 `Product not found.`
2. `!is_available` → 422 `{name} is currently unavailable.`
3. `stock < quantity` → 422 `Insufficient stock for {name}.`
4. **Atomically decrement stock** inside a transaction (pessimistic row locks).
5. On any failure the whole validate call must roll back (no stock consumed).

Response:

```json
{
  "store": { "id": 1, "name": "...", "slug": "...", "status": "ACTIVE",
             "latitude": "14.5", "longitude": "121.0", "address": "...", "phone": null },
  "items": [ { "productId": 42, "name": "...", "quantity": 2,
               "unitPrice": "99.00", "subtotal": "198.00" } ],
  "subtotal": "198.00"
}
```

### 1.4 order-service (DB: taladelivery_order)

| Method | Path | Auth | Request body | Response `data` |
| --- | --- | --- | --- | --- |
| GET | `/internal/orders/:id` | service | – | `OrderStatusProjection` **+ `items`** (see below) |
| GET | `/internal/orders/by-number/:orderNumber` | service | – | `OrderStatusProjection` + `items` |
| GET | `/internal/orders/by-delivery/:deliveryId` | service | – | `OrderStatusProjection` + `items` |
| GET | `/internal/admin/totals` | service | – | `{ orders, pendingOrders, todayOrders, todayDelivered, todayRevenue }` |

`OrderStatusProjection` (in `libs/contracts/.../common.ts`) plus `items`:

```json
{ "...OrderStatusProjection fields...",
  "items": [ { "id": 1, "productId": 42, "productName": "...", "quantity": 2,
               "unitPrice": "99.00", "subtotal": "198.00" } ] }
```

Order service is the **single writer** for `orders` and `order_items` rows. It owns order
numbers (`TLD-Ymd-6xUPPER`), order-level state transitions, and stock restoration via
catalog events (see §2).

### 1.5 dispatch-service (DB: taladelivery_dispatch)

| Method | Path | Auth | Request body | Response `data` |
| --- | --- | --- | --- | --- |
| POST | `/internal/pricing/calculate` | service | `{ pickupLatitude, pickupLongitude, deliveryLatitude, deliveryLongitude, city, province }` | see below |
| POST | `/internal/riders` | service | `{ userId, vehicleType, vehiclePlate?, licenseNumber?, requirements? }` | `RiderProfileSnapshot` |
| GET | `/internal/riders/by-user/:userId` | service | – | `RiderProfileSnapshot` |
| POST | `/internal/deliveries` | service | see below | `DeliverySnapshot` |
| GET | `/internal/deliveries/:id` | service | – | `DeliverySnapshot` |
| POST | `/internal/deliveries/:id/cancel` | service | `{ cancelledBy, reason? }` | `DeliverySnapshot` |
| GET | `/internal/admin/totals` | service | – | `{ riders, deliveries, onlineRiders }` |

`POST /internal/pricing/calculate` response data:

```json
{
  "deliveryFee": "112.00",
  "distanceKm": "4.2",
  "billableDistanceKm": "4.5",
  "distanceMethod": "STRAIGHT_LINE",
  "zone": { "id": 1, "name": "...", "city": "...", "province": "...",
            "baseFee": "49.00", "includedKm": "3.00", "extraFeePerKm": "10.00",
            "maximumDeliveryKm": null, "maximumDeliveryFee": null,
            "distanceRoundingKm": "0.10", "status": "ACTIVE" },
  "riderCommission": "11.20",
  "commissionType": "PERCENTAGE",
  "commissionValue": "10.00"
}
```

Errors (422, Laravel-exact): `A valid pickup and delivery location is required to place an order.`,
`A city is required to calculate the delivery fee.`, `A province is required to calculate the delivery fee.`,
`Delivery is not available in the selected city.`, `Road distance is temporarily unavailable. Please try again.`,
`Delivery distance exceeds this zone's {max} km limit.`

`POST /internal/deliveries` request:

```json
{
  "orderId": 1,
  "storeId": 1,
  "pickupAddress": "...", "pickupLatitude": "14.5", "pickupLongitude": "121.0",
  "deliveryAddress": "...", "deliveryLatitude": "14.6", "deliveryLongitude": "121.1",
  "distanceKm": "4.20", "deliveryFee": "112.00",
  "riderCommission": "11.20", "commissionType": "PERCENTAGE", "commissionValue": "10.00"
}
```

Creates a `delivery` with `status: UNASSIGNED`, returns `DeliverySnapshot` (contracts lib).

### 1.6 payment-service / notification-service / realtime-service

| Service | Endpoint | Response `data` |
| --- | --- | --- |
| payment | `GET /internal/admin/totals` | `{ payments, collectedToday }` |
| notification | `GET /internal/notifications/health` | `{ mode: "fcm"\|"stub", pending: number }` |
| realtime | `GET /internal/admin/totals` | `{ connectedSockets, rooms }` |

## 2. BullMQ event contracts

Queue names (`QueueName` in `@taladelivery/events`): `order-events`, `delivery-events`,
`payment-events`, `notification-jobs`, `offer-expiry`, `location-events`.

Every event is an `EventEnvelope` (`eventId`, `eventType`, `eventVersion`, `occurredAt`,
`correlationId`, `data`) published via `EventPublisher.publishEvent(queue, type, data, corr)`.

Consumers register with `EventWorkerManager.on(queueName, handler, { eventTypes })`; the lib
already dedupes by `eventId` (Redis SET NX) and retries with backoff.

### Producers / consumers matrix

| eventType | Publish (queue) | data | Consumed by |
| --- | --- | --- | --- |
| `order.created` | order (`order-events`) | `{ orderId, orderNumber, customerId, storeId, deliveryId, status, total }` | notification, realtime |
| `order.confirmed` | order | `{ orderId, orderNumber, status }` | notification, realtime |
| `order.preparing` | order | same | notification, realtime |
| `order.ready_for_pickup` | order | `{ orderId, orderNumber, deliveryId }` | **dispatch** (match), notification, realtime |
| `order.cancelled` | order | `{ orderId, orderNumber, cancelledBy, reason }` | dispatch (cancel delivery), notification, realtime |
| `order.delivered` | order | `{ orderId, orderNumber }` | notification, realtime |
| `order.rider_assigned` | order-service after `delivery.assigned` | `{ orderId, orderNumber, riderId }` | notification, realtime |
| `dispatch.offer_created` | dispatch (`delivery-events`) | `{ deliveryId, offerId, riderId, expiresAt }` | realtime (→ rider.offer), notification |
| `dispatch.offer_rejected` | dispatch | `{ deliveryId, offerId, riderId }` | realtime |
| `dispatch.offer_expired` | dispatch | `{ deliveryId, offerId, riderId }` | realtime, notification (rider) |
| `dispatch.rider_assigned` | dispatch | `{ deliveryId, orderId, riderId }` | realtime (→ rider.assigned), notification |
| `delivery.assigned` | dispatch (`delivery-events`) | `{ deliveryId, orderId, riderId, status }` | **order-service** (→ RIDER_ASSIGNED), realtime |
| `delivery.rider_arrived` | dispatch | `{ deliveryId, orderId }` | notification (merchant), realtime |
| `delivery.picked_up` | dispatch | `{ deliveryId, orderId }` | **order-service** (→ PICKED_UP), notification, realtime |
| `delivery.out_for_delivery` | dispatch | `{ deliveryId, orderId }` | **order-service** (→ OUT_FOR_DELIVERY), notification, realtime |
| `delivery.delivered` | dispatch | `{ deliveryId, orderId, riderId }` | **order-service** (→ DELIVERED + payment PAID), payment (COD capture), notification, realtime |
| `delivery.cancelled` | dispatch | `{ deliveryId, orderId, cancelledBy, reason }` | **order-service** (→ CANCELLED, keep stock restore order), notification, realtime |
| `rider.location.updated` | dispatch (`location-events`) | `{ deliveryId, riderId, latitude, longitude, accuracyM?, headingDeg?, speedMps?, recordedAt }` | realtime (broadcast to order room) |
| `notification.create` | any service (`notification-jobs`) | `{ userId, type, title, body, data? }` | notification (store row + push/stub) |
| `payment.created` / `payment.paid` / `payment.failed` / `payment.refunded` | payment (`payment-events`) | `{ paymentId, orderId, amount, method, status }` | order (projection), notification, realtime |

**Dispatch → order delivery-status contract**: order-service consumes `delivery.assigned`,
`delivery.picked_up`, `delivery.out_for_delivery`, `delivery.delivered`, `delivery.cancelled`
and applies the Laravel-exact order transitions:
- `delivery.assigned` → order `RIDER_ASSIGNED` (publish `order.rider_assigned`)
- `delivery.picked_up` → order `PICKED_UP`
- `delivery.out_for_delivery` → order `OUT_FOR_DELIVERY`
- `delivery.delivered` → order `DELIVERED` **and** order `payment_status` `PAID`
- `delivery.cancelled` → order `CANCELLED` (unless already DELIVERED/CANCELLED), `cancelled_by`, `cancellation_reason`, `cancelled_at`; then publish `order.cancelled`. Stock restore for admin-initiated delivery cancel is done by order-service via catalog (`POST /internal/orders/:orderId/restore-stock` or event — **use catalog internal endpoint** `POST /internal/orders/restore` with `{ items: [{productId, quantity}] }`).

### Offer expiry

Dispatch schedules a delayed job on `offer-expiry` (delay = `OFFER_TTL_SECONDS` × 1000, default 300s)
with an `EventEnvelope` of type `dispatch.offer_expired`. Handler: if offer still PENDING → mark
EXPIRED (+ `responded_at`), publish `dispatch.offer_expired`, and if delivery unassigned →
`matchNext(delivery)`.

## 3. Order-create orchestration (order-service, `POST /v1/orders`)

1. `merchant-service GET /internal/stores/:id` → store; if not ACTIVE → 422 `This store is not accepting orders right now.`
2. `catalog-service POST /internal/orders/validate` with body `{ storeId, items }` → subtotal, line items, store snapshot.
3. `dispatch-service POST /internal/pricing/calculate` with pickup = store coordinates, delivery = body `delivery_latitude/longitude`, `city`, `province` → fee + distance.
4. Insert order + items (snapshots) in order DB. Rounding: **minor-unit integer arithmetic**; serialize decimal strings.
   `total = subtotal + deliveryFee - discount`.
5. `dispatch-service POST /internal/deliveries` → delivery row; store `deliveryId` back on order.
6. Publish `order.created` (queue `order-events`).
7. Request idempotency: `IdempotencyKeyPrefix.OrderCreate` + user id + normalized items hash in Redis (`SET NX EX 3600`).

## 4. Rider registration (`POST /v1/rider/register`)

Implemented by **identity-service**:
1. Validate body. Create user (`role: rider`, `status: ACTIVE`) in identity DB.
2. `dispatch-service POST /internal/riders` → rider profile (`status: PENDING`).
3. Issue token pair. Respond `{ token, user }` (201), message `Rider application submitted. Please wait for admin approval.`

## 5. Gateway proxying

The gateway is a thin proxy: forwards to service ports, injects `X-App-Key`, forwards
`x-user-*` / `x-correlation-id` / `x-request-id` / `x-store-id` headers. It does **not**
inspect/produce business data. Public routes (`/auth/*`, `/stores`, `/products`, `/rider/register`)
and health routes are proxied to the owning service.