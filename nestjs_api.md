# TalaDelivery --- Laravel to NestJS Microservices Migration

**Version:** 1.0\
**Goal:** Use the existing working Laravel TalaDelivery backend to
validate business processes, then progressively rebuild those validated
processes in NestJS microservices and eventually retire Laravel.

------------------------------------------------------------------------

# 1. Migration Principle

TalaDelivery will not perform a big-bang rewrite.

The existing Laravel backend remains the **working reference
implementation** while the NestJS production architecture is developed.

``` text
Laravel
   │
   │ Build + Test Business Process
   ▼
Process Confirmed Working
   │
   │ Document Expected Behavior
   ▼
NestJS Implementation
   │
   │ Compare + Test
   ▼
NestJS Staging
   │
   ▼
Production Cutover
   │
   ▼
Laravel Archived
```

Laravel and NestJS must **not write to the same production database**
during the migration.

------------------------------------------------------------------------

# 2. Final Target Architecture

``` text
Customer Flutter ───┐
Rider Flutter ──────┤
Merchant Angular ───┼────► API Gateway
Admin Angular ──────┘          │
                               ▼
                            NestJS
                               │
         ┌─────────────────────┼──────────────────────┐
         │                     │                      │
         ▼                     ▼                      ▼
     Identity              Merchant                Catalog
     Service               Service                 Service
         │                     │                      │
         ▼                     ▼                      ▼
   identity_db           merchant_db             catalog_db

                               │
                               ▼
                         Order Service
                               │
                               ▼
                           order_db
                               │
                        Domain Events
                               │
                               ▼
                         Redis / BullMQ
                               │
              ┌────────────────┼────────────────┐
              ▼                ▼                ▼
          Dispatch          Payment       Notification
          Service           Service          Service
              │                │
              ▼                ▼
         dispatch_db       payment_db
              │
              ▼
        Realtime Service
              │
           WebSocket
              │
      ┌───────┼────────┐
      ▼       ▼        ▼
   Customer  Rider   Merchant
```

------------------------------------------------------------------------

# Phase 0 --- Freeze the Architecture

## Goal

Define what Laravel currently does and what the NestJS replacement must
reproduce.

## Laravel

Keep the existing Laravel API operational.

Do not begin major architectural rewrites inside Laravel.

Laravel becomes:

``` text
Working Prototype
+
Business Rule Reference
+
API Behavior Reference
+
Fallback During Migration
```

## Tasks

-   [ ] Back up Laravel repository *(operational — handle directly)*
-   [ ] Back up current PostgreSQL database *(operational — handle directly)*
-   [ ] Tag stable Laravel version *(operational — handle directly)*
-   [x] Document existing API endpoints
-   [x] Document order statuses
-   [x] Document delivery statuses
-   [x] Document rider matching
-   [x] Document delivery pricing
-   [x] Document permissions
-   [x] Document notification behavior
-   [x] Document cancellation rules
-   [x] Document commission rules

## Result

``` text
Laravel = known-good reference
NestJS implementation = validated business process reference
```

---

## Phase 0 Documentation

### API Endpoints

#### Public Customer-Facing

| Method | Path | Auth | Service | Description |
|--------|------|------|---------|-------------|
| POST | `/api/v1/auth/register` | App Key | Identity | Customer registration |
| POST | `/api/v1/auth/login` | App Key | Identity | Customer login |
| POST | `/api/v1/auth/refresh` | App Key | Identity | Refresh token rotation |
| POST | `/api/v1/auth/logout` | JWT | Identity | Logout (revokes refresh family) |
| GET | `/api/v1/auth/me` | JWT | Identity | Current user profile |
| PUT | `/api/v1/auth/profile` | JWT | Identity | Update profile |
| GET | `/api/v1/stores` | App Key | Merchant | List stores (paginated) |
| GET | `/api/v1/stores/:id` | App Key | Merchant | Store details |
| GET | `/api/v1/stores/:id/profile` | JWT + Store Membership | Merchant | Store profile (merchant admin) |
| GET | `/api/v1/stores/:id/categories` | App Key | Catalog | Store categories |
| GET | `/api/v1/stores/:id/products` | App Key | Catalog | Store products |
| GET | `/api/v1/products` | App Key | Catalog | Browse all products |
| GET | `/api/v1/products/:id` | App Key | Catalog | Product details |
| POST | `/api/v1/orders` | JWT (Customer) | Order | Create order |
| GET | `/api/v1/orders` | JWT (Customer) | Order | List customer orders |
| GET | `/api/v1/orders/:id` | JWT (Customer) | Order | Order details |
| POST | `/api/v1/orders/:id/cancel` | JWT (Customer) | Order | Cancel order |
| GET | `/api/v1/payments` | JWT (Customer) | Payment | List customer payments |
| GET | `/api/v1/payments/:id` | JWT (Customer) | Payment | Payment details |

#### Rider-Facing

| Method | Path | Auth | Service | Description |
|--------|------|------|---------|-------------|
| POST | `/api/v1/rider/register` | App Key | Identity | Rider application (creates user + dispatch profile) |
| GET | `/api/v1/rider/profile` | JWT (Rider) | Dispatch | Rider profile + stats + current delivery |
| POST | `/api/v1/rider/online` | JWT (Rider) | Dispatch | Go online |
| POST | `/api/v1/rider/offline` | JWT (Rider) | Dispatch | Go offline |
| POST | `/api/v1/rider/location` | JWT (Rider) | Dispatch | Update GPS location |
| GET | `/api/v1/rider/deliveries` | JWT (Rider) | Dispatch | Rider delivery history |
| GET | `/api/v1/rider/earnings-summary` | JWT (Rider) | Dispatch | Earnings (today/week/month) |
| GET | `/api/v1/rider/offers` | JWT (Rider) | Dispatch | Pending offers |
| POST | `/api/v1/rider/offers/:offer/accept` | JWT (Rider) | Dispatch | Accept delivery offer |
| POST | `/api/v1/rider/offers/:offer/reject` | JWT (Rider) | Dispatch | Reject delivery offer |
| POST | `/api/v1/rider/deliveries/:delivery/arrived` | JWT (Rider) | Dispatch | Arrived at store |
| POST | `/api/v1/rider/deliveries/:delivery/pickup` | JWT (Rider) | Dispatch | Picked up order |
| POST | `/api/v1/rider/deliveries/:delivery/start` | JWT (Rider) | Dispatch | Start delivery trip |
| POST | `/api/v1/rider/deliveries/:delivery/complete` | JWT (Rider) | Dispatch | Complete delivery |

#### Merchant-Facing

| Method | Path | Auth | Service | Description |
|--------|------|------|---------|-------------|
| POST | `/api/v1/merchant/products` | JWT (Store Admin) | Catalog | Create product |
| PUT | `/api/v1/merchant/products/:id` | JWT (Store Admin) | Catalog | Update product |
| DELETE | `/api/v1/merchant/products/:id` | JWT (Store Admin) | Catalog | Delete product |
| GET | `/api/v1/merchant/profile` | JWT (Store Admin) | Merchant | Own store profile |
| PUT | `/api/v1/merchant/profile` | JWT (Store Admin) | Merchant | Update own store |

#### Admin-Facing (Platform Admin)

| Method | Path | Auth | Service | Description |
|--------|------|------|---------|-------------|
| POST | `/api/v1/stores` | JWT (Admin) | Merchant | Create store |
| PUT | `/api/v1/stores/:id` | JWT (Admin) | Merchant | Update store |
| GET | `/api/v1/admin/stores` | JWT (Admin) | Merchant | List stores, all statuses (`search`, `status`, `page`, `per_page`) |
| GET | `/api/v1/admin/stores/:id` | JWT (Admin) | Merchant | Store details |
| POST | `/api/v1/admin/stores` | JWT (Admin) | Merchant | Create store |
| PUT | `/api/v1/admin/stores/:id` | JWT (Admin) | Merchant | Update store |
| GET | `/api/v1/admin/customers` | JWT (Admin) | Identity | List customers (`search`, `status`, `page`, `per_page`) |
| GET | `/api/v1/admin/users` | JWT (Admin) | Identity | List platform admins (`search`, `status`, `page`, `per_page`) |
| GET | `/api/v1/admin/users/:id` | JWT (Admin) | Identity | Platform admin details |
| POST | `/api/v1/admin/users` | JWT (Admin) | Identity | Create platform admin |
| PUT | `/api/v1/admin/users/:id/password` | JWT (Admin) | Identity | Reset admin password (revokes sessions) |
| PUT | `/api/v1/admin/users/:id/status` | JWT (Admin) | Identity | Enable/disable/suspend admin |
| GET | `/api/v1/admin/dashboard` | JWT (Admin) | Dispatch | Platform dashboard totals |
| GET | `/api/v1/admin/riders` | JWT (Admin) | Dispatch | List riders |
| GET | `/api/v1/admin/riders/:rider` | JWT (Admin) | Dispatch | Rider details |
| POST | `/api/v1/admin/riders/:rider/approve` | JWT (Admin) | Dispatch | Approve rider |
| POST | `/api/v1/admin/riders/:rider/reject` | JWT (Admin) | Dispatch | Reject rider |
| POST | `/api/v1/admin/riders/:rider/suspend` | JWT (Admin) | Dispatch | Suspend rider |
| GET | `/api/v1/admin/deliveries` | JWT (Admin) | Dispatch | List deliveries |
| GET | `/api/v1/admin/deliveries/:delivery` | JWT (Admin) | Dispatch | Delivery details |
| POST | `/api/v1/admin/deliveries/:delivery/assign` | JWT (Admin) | Dispatch | Manual rider assignment |
| POST | `/api/v1/admin/deliveries/:delivery/cancel` | JWT (Admin) | Dispatch | Cancel delivery |
| GET | `/api/v1/admin/delivery-zones` | JWT (Admin) | Dispatch | List delivery zones |
| POST | `/api/v1/admin/delivery-zones` | JWT (Admin) | Dispatch | Create delivery zone |
| GET | `/api/v1/admin/delivery-zones/:zone` | JWT (Admin) | Dispatch | Zone details + revisions |
| PUT | `/api/v1/admin/delivery-zones/:zone` | JWT (Admin) | Dispatch | Update zone |
| DELETE | `/api/v1/admin/delivery-zones/:zone` | JWT (Admin) | Dispatch | Archive zone |
| GET | `/api/v1/admin/delivery-zones/:zone/pricing-preview` | JWT (Admin) | Dispatch | Preview pricing for zone |
| PUT | `/api/v1/admin/platform-settings` | JWT (Admin) | Dispatch | Update dispatch settings |
| GET | `/api/v1/admin/payments` | JWT (Admin) | Payment | List all payments |
| GET | `/api/v1/admin/payments/:id` | JWT (Admin) | Payment | Payment details |
| POST | `/api/v1/admin/payments/:id/refund` | JWT (Admin) | Payment | Refund payment |
| GET | `/api/v1/admin/place-boundaries` | JWT (Admin) | Dispatch | Search place boundaries |
| POST | `/api/v1/admin/place-boundaries` | JWT (Admin) | Dispatch | Create place boundary |

#### Internal (Service-to-Service, `X-Service-Token` required)

| Method | Path | Service | Description |
|--------|------|---------|-------------|
| POST | `/internal/users` | Identity | Create user |
| GET | `/internal/users/:id` | Identity | Get user by ID |
| GET | `/internal/users/by-email/:email` | Identity | Get user by email |
| GET | `/internal/users/batch?ids=1,2,3` | Identity | Batch get users |
| GET | `/internal/admin/totals` | Identity | Customer count |
| GET | `/internal/stores/:id` | Merchant | Store snapshot |
| GET | `/internal/stores/batch?ids=1,2` | Merchant | Batch store snapshots |
| POST | `/internal/stores` | Merchant | Create store |
| POST | `/internal/store-users` | Merchant | Add user to store |
| POST | `/internal/store-users/verify` | Merchant | Verify store membership |
| GET | `/internal/stores/:id/store-users` | Merchant | List store user IDs |
| GET | `/internal/admin/totals` | Merchant | Store count |
| POST | `/internal/orders/validate` | Catalog | Validate order items + stock |
| GET | `/internal/admin/totals` | Catalog | Product + category counts |
| GET | `/internal/orders/:id` | Order | Order projection + items |
| GET | `/internal/orders/by-number/:orderNumber` | Order | Order by order number |
| GET | `/internal/orders/by-delivery/:deliveryId` | Order | Order by delivery ID |
| GET | `/internal/admin/totals` | Order | Order totals |
| POST | `/internal/pricing/calculate` | Dispatch | Calculate delivery fee |
| POST | `/internal/riders` | Dispatch | Create rider profile |
| GET | `/internal/riders/by-user/:userId` | Dispatch | Rider by user ID |
| POST | `/internal/deliveries` | Dispatch | Create delivery |
| GET | `/internal/deliveries/:id` | Dispatch | Delivery snapshot |
| POST | `/internal/deliveries/:id/cancel` | Dispatch | Cancel delivery |
| GET | `/internal/admin/totals` | Dispatch | Rider + delivery counts |
| GET | `/internal/payments/:id` | Payment | Payment snapshot |
| GET | `/internal/payments/by-order/:orderId` | Payment | Payment by order |
| POST | `/internal/payments/:id/capture` | Payment | Capture payment |
| POST | `/internal/payments/:id/fail` | Payment | Fail payment |
| GET | `/internal/admin/totals` | Payment | Payment totals |
| GET | `/internal/notifications/health` | Notification | Notification service health |
| GET | `/internal/admin/totals` | Realtime | WebSocket stats |

---

### Order Statuses

Defined in `libs/contracts/src/enums.ts` — `OrderStatus`:

| Status | Value | Description |
|--------|-------|-------------|
| Pending | `PENDING` | Order created, awaiting merchant confirmation |
| Confirmed | `CONFIRMED` | Merchant confirmed, preparing |
| Preparing | `PREPARING` | Food/items being prepared |
| ReadyForPickup | `READY_FOR_PICKUP` | Ready for rider pickup |
| RiderAssigned | `RIDER_ASSIGNED` | Rider assigned (via dispatch offer accept) |
| PickedUp | `PICKED_UP` | Rider picked up from store |
| OutForDelivery | `OUT_FOR_DELIVERED` | Rider en route to customer |
| Delivered | `DELIVERED` | Delivery completed |
| Cancelled | `CANCELLED` | Order cancelled |

#### Order State Machine (FSM)

Defined in `ORDER_TRANSITIONS` — mirrors Laravel `OrderService`:

``` text
PENDING ──► CONFIRMED ──► PREPARING ──► READY_FOR_PICKUP ──► RIDER_ASSIGNED ──► PICKED_UP ──► OUT_FOR_DELIVERY ──► DELIVERED
   │              │              │                │                    │                  │                  │
   └──────────────┴──────────────┴────────────────┴────────────────────┴──────────────────┴──────────────────┴──► CANCELLED
```

- `DELIVERED` and `CANCELLED` are terminal states
- Cancellation is allowed from any non-terminal state
- `RIDER_ASSIGNED` can only transition to `CANCELLED` (not back to `READY_FOR_PICKUP`)

#### Order Events (published to `order-events` queue)

| Event | Trigger | Consumers |
|-------|---------|-----------|
| `order.created` | Order row inserted | notification, realtime |
| `order.confirmed` | Merchant confirms | notification, realtime |
| `order.preparing` | Merchant starts preparing | notification, realtime |
| `order.ready_for_pickup` | Merchant marks ready | **dispatch** (match), notification, realtime |
| `order.cancelled` | Order cancelled | dispatch (cancel delivery), notification, realtime |
| `order.delivered` | Delivery completed | notification, realtime |
| `order.rider_assigned` | After `delivery.assigned` | notification, realtime |

---

### Delivery Statuses

Defined in `libs/contracts/src/enums.ts` — `DeliveryStatus`:

| Status | Value | Description |
|--------|-------|-------------|
| Unassigned | `UNASSIGNED` | Delivery created, no rider yet |
| Assigned | `ASSIGNED` | Rider accepted offer (or admin assigned) |
| Accepted | `ACCEPTED` | Rider arrived at store |
| PickedUp | `PICKED_UP` | Rider picked up order |
| InTransit | `IN_TRANSIT` | Rider en route to customer |
| Delivered | `DELIVERED` | Delivery completed |
| Failed | `FAILED` | Delivery failed |
| Cancelled | `CANCELLED` | Delivery cancelled |

#### Delivery State Machine

``` text
UNASSIGNED ──► ASSIGNED ──► ACCEPTED ──► PICKED_UP ──► IN_TRANSIT ──► DELIVERED
     │              │            │            │              │
     └──────────────┴────────────┴────────────┴──────────────┴──► CANCELLED
```

#### Delivery Offer Statuses

| Status | Value | Description |
|--------|-------|-------------|
| Pending | `PENDING` | Offer sent to rider, awaiting response |
| Accepted | `ACCEPTED` | Rider accepted |
| Rejected | `REJECTED` | Rider rejected |
| Expired | `EXPIRED` | Offer TTL elapsed without response |

#### Delivery Events (published to `delivery-events` queue)

| Event | Trigger | Consumers |
|-------|---------|-----------|
| `delivery.assigned` | Rider assigned | **order-service** (→ RIDER_ASSIGNED), realtime |
| `delivery.rider_arrived` | Rider arrives at store | notification (merchant), realtime |
| `delivery.picked_up` | Rider picks up | **order-service** (→ PICKED_UP), notification, realtime |
| `delivery.out_for_delivery` | Rider starts trip | **order-service** (→ OUT_FOR_DELIVERY), notification, realtime |
| `delivery.delivered` | Delivery completed | **order-service** (→ DELIVERED + payment PAID), payment (COD capture), notification, realtime |
| `delivery.cancelled` | Delivery cancelled | **order-service** (→ CANCELLED), notification, realtime |
| `dispatch.offer_created` | Offer created | realtime (→ rider.offer), notification |
| `dispatch.offer_rejected` | Offer rejected | realtime |
| `dispatch.offer_expired` | Offer expired | realtime, notification (rider) |
| `dispatch.rider_assigned` | Rider assigned | realtime (→ rider.assigned), notification |

---

### Rider Matching

Implemented in `apps/dispatch-service/src/services/rider-matching.service.ts`.

#### Algorithm

``` text
order.ready_for_pickup event received
        ↓
Find delivery (UNASSIGNED, no rider)
        ↓
Check no pending offer exists
        ↓
Query ONLINE riders with known location
        ↓
Filter out already-offered riders
        ↓
Calculate Haversine distance to pickup
        ↓
Sort by distance (nearest first)
        ↓
Select nearest rider
        ↓
Create DeliveryOffer (PENDING, TTL = OFFER_TTL_SECONDS)
        ↓
Schedule expiry job (delayed BullMQ)
        ↓
Publish dispatch.offer_created event
```

#### Offer Acceptance (Concurrency-Safe)

``` text
BEGIN TRANSACTION
  SELECT ... FOR UPDATE (pessimistic lock on offer)
  Validate: offer exists, belongs to rider, still PENDING, not expired
  SELECT ... FOR UPDATE (pessimistic lock on delivery)
  Validate: delivery still UNASSIGNED, no rider
  Validate: rider not BUSY or SUSPENDED
  UPDATE offer → ACCEPTED
  UPDATE delivery → ASSIGNED (set riderId, assignedAt)
  UPDATE rider → BUSY
  PUBLISH dispatch.rider_assigned + delivery.assigned
COMMIT
```

#### Offer Rejection

``` text
BEGIN TRANSACTION
  SELECT ... FOR UPDATE (pessimistic lock on offer)
  Validate: offer exists, belongs to rider, still PENDING
  UPDATE offer → REJECTED
  PUBLISH dispatch.offer_rejected
  matchNext(delivery) → find next nearest rider
COMMIT
```

#### Offer Expiry

- Scheduled via BullMQ delayed job on `offer-expiry` queue
- Delay = `OFFER_TTL_SECONDS` (default 300s / 5 minutes)
- Handler: if offer still PENDING → mark EXPIRED, publish `dispatch.offer_expired`, call `matchNext(delivery)`

#### Manual Admin Assignment

- Admin can assign any active rider to an unassigned delivery
- Expires all pending offers for that delivery
- Same transactional safety as offer acceptance

---

### Delivery Pricing

Implemented in `apps/dispatch-service/src/services/pricing.service.ts`.

#### Formula

``` text
distance = Haversine(pickup, delivery)  [or RoadRoute if configured]

billableDistance = ceil(distance / roundingKm) * roundingKm

extraKm = max(0, billableDistance - includedKm)

deliveryFee = baseFee + (extraFeePerKm * extraKm)

deliveryFee = min(deliveryFee, maximumDeliveryFee)  [if set]
```

#### Zone Resolution

``` text
1. If delivery coordinates fall inside a zone's GeoJSON boundary → use that zone
2. Otherwise, match by city + province (case-insensitive)
3. "City" suffix is stripped for matching (e.g. "Makati City" matches "Makati")
4. Only ACTIVE zones with effective_from <= now are considered
5. Zones ordered by ID (first match wins)
```

#### Distance Methods

| Method | Value | Description |
|--------|-------|-------------|
| Straight-line | `STRAIGHT_LINE` | Haversine formula (default) |
| Road route | `ROAD_ROUTE` | External road distance API |

#### Zone Configuration Fields

| Field | Type | Description |
|-------|------|-------------|
| `base_fee` | decimal | Base delivery fee |
| `included_km` | decimal | Kilometers included in base fee |
| `extra_fee_per_km` | decimal | Per-km charge beyond included distance |
| `maximum_delivery_km` | decimal/null | Maximum allowed distance |
| `maximum_delivery_fee` | decimal/null | Cap on total delivery fee |
| `distance_rounding_km` | decimal | Rounding increment (default 0.1) |
| `boundary_geojson` | GeoJSON/null | Zone boundary polygon |
| `city` | string | City name (for non-boundary zones) |
| `province` | string | Province name |
| `effective_from` | datetime/null | Zone activation date |
| `status` | enum | DRAFT, ACTIVE, SUSPENDED, ARCHIVED |

#### Error Messages (Laravel-exact)

- `A valid pickup and delivery location is required to place an order.`
- `A city is required to calculate the delivery fee.`
- `A province is required to calculate the delivery fee.`
- `Delivery is not available in the selected city.`
- `Road distance is temporarily unavailable. Please try again.`
- `Delivery distance exceeds this zone's {max} km limit.`

---

### Permissions

#### Roles

Defined in `libs/contracts/src/enums.ts` — `Role`:

| Role | Value | Description |
|------|-------|-------------|
| Platform Admin | `platform_admin` | Full system access |
| Store Admin | `store_admin` | Manage own store |
| Rider | `rider` | Delivery rider |
| Customer | `customer` | End customer |

#### User Statuses

| Status | Value | Description |
|--------|-------|-------------|
| Active | `ACTIVE` | Can authenticate |
| Inactive | `INACTIVE` | Cannot authenticate |
| Suspended | `SUSPENDED` | Cannot authenticate |

#### Guards

| Guard | Purpose |
|-------|---------|
| `AppKeyGuard` | Validates `X-App-Key` header on public routes |
| `JwtAuthGuard` | Validates JWT access token |
| `RolesGuard` | Validates user role against `@Roles()` decorator |
| `ServiceAuthGuard` | Validates `X-Service-Token` for internal endpoints |

#### Route Protection Matrix

| Route Pattern | Auth Required |
|---------------|---------------|
| `/auth/register`, `/auth/login`, `/auth/refresh` | App Key only |
| `/stores` (GET), `/products` (GET) | App Key only |
| `/rider/register` | App Key only |
| `/auth/me`, `/auth/profile`, `/auth/logout` | JWT |
| `/orders` (customer) | JWT (Customer) |
| `/rider/*` | JWT (Rider) |
| `/merchant/*` | JWT (Store Admin) + store membership |
| `/admin/*` | JWT (Platform Admin) |
| `/internal/*` | Service Token |

---

### Notification Behavior

#### Channels

| Channel | Status | Description |
|---------|--------|-------------|
| FCM | Planned | Firebase Cloud Messaging push |
| WebSocket | Planned | Real-time socket delivery |
| In-App | Planned | Stored notification rows |

#### Notification Events

**Customer notifications:**
- Order received, confirmed, preparing, ready for pickup
- Rider assigned, picked up, out for delivery, delivered, Cancelled

**Merchant notifications:**
- New order, customer cancelled, rider assigned, rider arrived

**Rider notifications:**
- New offer, offer expired, delivery assigned, pickup reminder
- Application approved, rejected, suspended

#### Notification Flow

``` text
Domain Event (order.*, delivery.*, dispatch.*)
        ↓
EventPublisher → notification-jobs queue
        ↓
NotificationService consumer
        ↓
Store notification row + push via FCM/stub
```

#### Notification Payload

```json
{
  "userId": 123,
  "type": "order.confirmed",
  "title": "Order Confirmed",
  "body": "Your order #TLD-20260929-ABC123 has been confirmed.",
  "data": { "orderId": 456 }
}
```

---

### Cancellation Rules

#### Order Cancellation

- **Who can cancel:** Customer (own orders), Merchant (store orders), Admin (any order)
- **When:** Any non-terminal status (before DELIVERED or CANCELLED)
- **Side effects:**
  - Stock restored via catalog service (`POST /internal/orders/restore`)
  - Delivery cancelled (if assigned)
  - Payment refunded (if PAID)
  - `order.cancelled` event published

#### Delivery Cancellation

- **Who can cancel:** Admin, Order Service (via order cancellation)
- **When:** Any non-terminal delivery status
- **Side effects:**
  - Rider set back to ONLINE (if was BUSY)
  - Pending offers expired
  - `delivery.cancelled` event published
  - Order Service updates order status to CANCELLED

#### Rider Rejection

- A rider can reject any pending offer
- Rejection triggers `matchNext()` to find the next nearest rider
- No penalty for rejection (configurable in future)

---

### Commission Rules

Implemented in `apps/dispatch-service/src/services/rider-commission.service.ts`.

#### Commission Types

| Type | Value | Calculation |
|------|-------|-------------|
| Fixed | `FIXED` | Fixed amount per delivery |
| Percentage | `PERCENTAGE` | Percentage of delivery fee |

#### Formula

``` text
FIXED:     commission = fixedValue
PERCENTAGE: commission = deliveryFee × (percentageValue / 100)
```

#### Platform Settings

Stored in `dispatch_settings` table (single row, key = `platform`):

| Setting | Type | Description |
|---------|------|-------------|
| `rider_commission_type` | enum | FIXED or PERCENTAGE |
| `rider_commission_value` | decimal | Commission amount/percentage |
| `earnings_week_type` | enum | ROLLING_SEVEN_DAYS or CALENDAR_WEEK |
| `week_starts_on` | int | Day of week (0=Sunday) |
| `settlement_timezone` | string | Timezone for earnings periods |
| `settlement_day_starts_at` | string | Time when settlement day starts (HH:MM) |
| `distance_method` | enum | STRAIGHT_LINE or ROAD_ROUTE |

#### Rider Earnings

- Earnings = sum of `rider_commission` for all DELIVERED deliveries in period
- Periods: today, this week, this month
- Week can be rolling 7-day or calendar week
- Settlement day can start at custom hour (e.g. 4:00 AM)
- All calculations use integer minor-unit arithmetic (centavos)

------------------------------------------------------------------------

# Phase 1 --- NestJS Foundation

## Goal

Create the new backend without affecting Laravel.

Recommended repository:

``` text
taladelivery-backend/
│
├── apps/
│   ├── api-gateway/
│   ├── identity-service/
│   ├── merchant-service/
│   ├── catalog-service/
│   ├── order-service/
│   ├── dispatch-service/
│   ├── payment-service/
│   ├── notification-service/
│   └── realtime-service/
│
├── libs/
│   ├── contracts/
│   ├── events/
│   ├── auth/
│   ├── common/
│   └── observability/
│
├── docker/
├── docker-compose.yml
├── nest-cli.json
└── package.json
```

## Infrastructure

Set up:

-   [x] NestJS monorepo
-   [x] TypeScript strict mode
-   [x] PostgreSQL
-   [x] Redis
-   [x] BullMQ
-   [x] Docker
-   [x] API Gateway
-   [x] environment configuration
-   [x] structured logging
-   [x] request IDs
-   [x] health checks
-   [x] Swagger/OpenAPI
-   [x] global validation
-   [x] global exception handling

### Gateway bugs found while wiring the frontends

The gateway had never successfully proxied a single request. Two independent
bugs, both fatal, both invisible until something actually called it:

-   **Every path was treated as gateway-owned.** `GATEWAY_OWNED_PREFIXES`
    contained `'/'` and membership was tested with `startsWith`, which matches
    every absolute path. So every request fell through to `next()` and Nest
    answered 404 for the whole API. The root path is now an exact-match check,
    and prefixes match on `prefix + '/'` so `/healthz` is not swallowed by
    `/health`.
-   **The proxy was mounted after the Nest router.** Express dispatches in
    registration order and `app.init()` mounts the router, so registering the
    proxy afterwards meant the router 404ed before the proxy ever ran — the
    comment in `main.ts` had the ordering backwards. The middleware is now
    registered before `app.init()` and calls `next()` only for gateway-owned
    paths.

Also added: notification role-scoped routes and the merchant-console routes;
`test/gateway-frontend-contract.mjs` (27 assertions) covers gateway routing,
the role-scoped feeds, and Socket.IO room authorization including that
`admin:platform` events do not leak to a store admin.

Socket.IO subscribe acknowledgements go through the standard response
envelope, so a client must read the ack from `data`, not the top level. A
test that reads the top level reads every refusal as a success.

## Development URLs

``` text
Laravel Reference
api-dev.delivery.tala-works.online

NestJS Development
api-v2-dev.delivery.tala-works.online

NestJS WebSocket
ws-v2-dev.delivery.tala-works.online
```

## Completion

``` text
GET /health

200 OK
```

must work for every service.

------------------------------------------------------------------------

# Phase 2 --- Microservice Databases

## Goal

Prepare independent service ownership.

One PostgreSQL server can initially contain:

``` text
PostgreSQL
│
├── taladelivery_identity
├── taladelivery_merchant
├── taladelivery_catalog
├── taladelivery_order
├── taladelivery_dispatch
├── taladelivery_payment
└── taladelivery_notification
```

## Rules

Each service:

``` text
OWNS
↓
one database/domain
```

Never:

``` text
Order Service
      │
      └──── SQL ────► identity_db
```

Instead:

``` text
Order Service
      │
      ├── API
      │
      └── Events
             ↓
       Identity Service
```

## Completion

-   [x] Separate migrations per service
-   [x] Separate DB credentials
-   [x] No cross-database foreign keys
-   [x] No cross-service SQL joins
-   [x] Docker networking configured
-   [x] Redis available

------------------------------------------------------------------------

# Phase 3 --- Identity Service

## Laravel Process

First confirm:

``` text
Register
↓
Login
↓
Authenticated Request
↓
Role Check
↓
Logout
```

## NestJS

Build:

``` text
identity-service
```

Own:

``` text
users
roles
permissions
user_roles
role_permissions
addresses
refresh_tokens
password_reset_tokens
```

Replace:

``` text
Laravel Sanctum
       ↓
NestJS JWT
+
Refresh Tokens
```

## Routes

``` text
POST /api/v1/auth/register
POST /api/v1/auth/login
POST /api/v1/auth/refresh
POST /api/v1/auth/logout
GET  /api/v1/auth/me
```

## Test

Run the same Flutter login flow against:

``` text
Laravel API
```

then:

``` text
NestJS API
```

Expected behavior should match.

## Completion

-   [x] Customer registration
-   [x] Rider authentication
-   [x] Merchant authentication
-   [x] Admin authentication
-   [x] JWT
-   [x] Refresh tokens
-   [x] RBAC
-   [x] Account status
-   [x] Addresses

------------------------------------------------------------------------

# Phase 4 --- Merchant Service

## Goal

Move store/merchant management.

Existing concept:

``` text
stores
store_users
```

becomes:

``` text
merchants
merchant_users
```

## Merchant Service Owns

``` text
Merchant
├── Profile
├── Address
├── Location
├── Opening hours
├── Status
└── Users
```

## Routes

``` text
GET  /api/v1/stores
GET  /api/v1/stores/:id

GET  /api/v1/merchant/profile
PUT  /api/v1/merchant/profile
```

Public route names can remain `/stores` initially to avoid breaking
Flutter.

## Completion

-   [x] Merchant listing
-   [x] Merchant details
-   [x] Merchant membership
-   [x] Merchant status
-   [x] Opening hours
-   [x] Location

### Implementation status (2026-09-29)

-   [x] Merchant service source, isolated `stores` / `store_users` ownership, and documented internal store-membership contracts implemented.
-   [x] Merchant service typecheck and production build verified.
-   [x] TypeORM CLI loads `.env` and TypeScript path aliases; merchant migration command connects successfully.
-   [x] Opening hours implemented (JSONB column on `stores` table, DTO validation, service persistence, snapshot inclusion).
-   [x] Committed, versioned merchant schema migration created and executed (`AddOpeningHoursToStores1727637200000`).

------------------------------------------------------------------------

# Phase 5 --- Catalog Service

## Goal

Move products/categories.

Own:

``` text
categories
products
```

## Structure

``` text
Merchant
   │
   ├── Category
   │      │
   │      └── Products
   │
   └── Category
          │
          └── Products
```

## Routes

``` text
GET /api/v1/stores/:id/categories
GET /api/v1/stores/:id/products

GET    /api/v1/products
GET    /api/v1/products/:id
POST   /api/v1/merchant/products
PUT    /api/v1/merchant/products/:id
DELETE /api/v1/merchant/products/:id
```

## Completion

-   [x] Categories entity + CRUD
-   [x] Products entity + CRUD
-   [x] Store-scoped product listing
-   [x] Merchant product management (create/update/delete)
-   [x] Public product browsing (paginated)
-   [x] Internal order validation (`POST /internal/orders/validate`)
-   [x] Internal admin totals (`GET /internal/admin/totals`)
-   [x] Database migration (`CreateCatalogTables1727637300000`)
-   [x] Build verified

Flutter Customer must be able to:

``` text
Browse Merchant
      ↓
Browse Category
      ↓
Browse Products
      ↓
Select Product
```

### Implementation status (2026-09-29)

-   [x] Catalog service source with `categories` and `products` entities, DTOs, services, and controllers implemented.
-   [x] Public routes: `GET /stores/:id/categories`, `GET /stores/:id/products`, `GET /products`, `GET /products/:id`.
-   [x] Merchant routes: `POST /merchant/products`, `PUT /merchant/products/:id`, `DELETE /merchant/products/:id`.
-   [x] Internal contract: `POST /internal/orders/validate` with atomic stock decrement, `GET /internal/admin/totals`.
-   [x] Migration `CreateCatalogTables1727637300000` executed — `categories` and `products` tables created.
-   [x] Build verified.

------------------------------------------------------------------------

# Phase 6 --- Order Service

## Goal

Move the most important TalaDelivery business process.

Own:

``` text
orders
order_items
```

## Status

``` text
PENDING
CONFIRMED
PREPARING
READY_FOR_PICKUP
RIDER_ASSIGNED
PICKED_UP
OUT_FOR_DELIVERY
DELIVERED
CANCELLED
```

## Flow

``` text
Customer
   ↓
Create Order
   ↓
PENDING
   ↓
Merchant Confirm
   ↓
CONFIRMED
   ↓
PREPARING
   ↓
READY_FOR_PICKUP
```

## Snapshot Rule

Order must save:

``` text
customer snapshot
merchant snapshot
product snapshot
price snapshot
pickup snapshot
delivery snapshot
```

Never depend on current product price for historical orders.

## Events

``` text
order.created
order.confirmed
order.preparing
order.ready_for_pickup
order.cancelled
order.delivered
```

## Completion

-   [x] Create order
-   [x] View order
-   [x] Cancel order
-   [x] Merchant confirmation
-   [x] Preparing
-   [x] Ready
-   [x] Status validation
-   [x] Order snapshots
-   [x] Domain events
-   [x] Idempotency

------------------------------------------------------------------------

# Phase 7 --- Redis + BullMQ Event Infrastructure

## Goal

Stop tightly coupling services.

Example:

``` text
Order Service
     │
     │ order.ready_for_pickup
     ▼
Redis / BullMQ
     │
     ├────► Dispatch
     ├────► Notification
     └────► Realtime
```

## Implement

-   [x] BullMQ
-   [x] retry policy
-   [x] failed jobs
-   [x] event IDs
-   [x] idempotent consumers
-   [x] dead-letter/failure handling
-   [x] logging
-   [x] event contracts

Later consider an Outbox Pattern.

Do not introduce Kafka yet unless actual requirements justify it.

------------------------------------------------------------------------

# Phase 8 --- Dispatch Service

## Goal

Rebuild your working Laravel rider-matching system.

Own:

``` text
riders
deliveries
delivery_offers
delivery_zones
delivery_zone_revisions
dispatch_settings
```

## Matching

``` text
Order READY
     ↓
Dispatch receives event
     ↓
Find ONLINE Riders
     ↓
Remove BUSY/SUSPENDED
     ↓
Calculate Distance
     ↓
Nearest Rider
     ↓
Create Offer
     ↓
30 Second Timer
```

Then:

``` text
             OFFER
               │
       ┌───────┼────────┐
       ▼       ▼        ▼
    ACCEPT   REJECT   EXPIRE
       │       │        │
       ▼       └────┬───┘
    Assign           │
    Rider            ▼
                Next Rider
```

## Critical Rule

Only one rider can accept.

Use:

``` text
database transaction
+
locking
+
idempotency
```

## Completion

-   [x] Rider online/offline
-   [x] Rider availability
-   [x] Rider location
-   [x] Matching
-   [x] 30-second offers
-   [x] Accept
-   [x] Reject
-   [x] Expiration
-   [x] Next rider
-   [x] Manual admin assignment
-   [x] Commission
-   [x] Delivery zones

------------------------------------------------------------------------

# Phase 9 --- Realtime Service

## Goal

Replace polling with proper realtime communication.

``` text
wss://ws.delivery.tala-works.online
```

## Realtime Service

``` text
NestJS
+
WebSocket Gateway
+
Socket.IO
+
Redis
```

## Rooms

``` text
user:{id}
customer:{id}
merchant:{id}
rider:{id}
order:{id}
```

## Events

``` text
order.created
order.confirmed
order.preparing
order.ready

rider.offer
rider.assigned

rider.location

delivery.picked_up
delivery.out_for_delivery
delivery.delivered
```

## Architecture

``` text
Rider Flutter
     │
     │ GPS
     ▼
Location/Realtime
     │
     ▼
Redis
     │
     ├────► Dispatch
     │
     └────► Customer WebSocket
```

Do not continuously write every GPS update to PostgreSQL.

Redis can hold current location.

PostgreSQL stores important/history data when necessary.

## Completion

-   [x] WebSocket gateway with Socket.IO
-   [x] JWT authentication on connection
-   [x] Room-based authorization (`user:`, `order:`, `merchant:`, `rider:`, `customer:`, `admin:platform`)
-   [x] Subscribe/unsubscribe handlers
-   [x] Rider location update handler (broadcasts to order room)
-   [x] `realtime-feed` consumer — other services push to rooms via `realtime.emit`
-   [x] `location-events` consumer — dispatch positions broadcast to `order:` / `rider:` rooms
-   [x] Internal stats endpoint (`GET /internal/admin/totals`)
-   [x] Build verified

### Implementation status (2026-09-30)

-   [x] Realtime service source with WebSocket gateway, JWT auth, room authorization, and location update handler implemented.
-   [x] Internal contract: `GET /internal/admin/totals` returns `{ connectedSockets, rooms }`.
-   [x] Gateway now uses `TokenService.verifyAccess` instead of a raw
      `jwt.verifyAsync`. The raw call did not check the token `type`, so a
      **refresh token was accepted as a socket credential**; it also had no
      `JwtService` provider and declared a `JWT_SECRET` read by nothing, so
      the gateway had never successfully booted before this.
-   [x] `admin:platform` room (platform admin only) for platform events.
-   [x] `realtime-feed` queue and `realtime.emit` contract, so order-service and
      identity-service can push to rooms (§20.14.2).
-   [x] Build and typecheck verified; service boots and drains both queues.
-   [ ] No integration test drives a live Socket.IO client — queue-level
      fan-out is verified, socket delivery is not.

------------------------------------------------------------------------

# Phase 10 --- Payment Service

## MVP

Start with:

``` text
COD
```

Own:

``` text
payments
payment_attempts
payment_webhook_events
refunds
```

## Flow

``` text
Order
  ↓
Payment Created
  ↓
COD
  ↓
Delivery Completed
  ↓
Payment PAID
```

Later:

``` text
Payment Service
├── COD
├── GCash
├── Maya
├── Card
└── Online Gateway
```

Payment Service becomes the authoritative source for payment state.

Order Service keeps only a payment-status projection.

## Completion

-   [x] COD
-   [x] Idempotency
-   [x] Payment events
-   [x] Payment status
-   [x] Webhook-ready design
-   [x] Refund-ready design

------------------------------------------------------------------------

# Phase 11 --- Notification Service

## Channels

``` text
FCM
WebSocket
In-App
```

## Events

Customer:

``` text
Order received
Order confirmed
Preparing
Ready
Rider assigned
Picked up
Out for delivery
Delivered
Cancelled
```

Merchant:

``` text
New order
Customer cancelled
Rider assigned
Rider arrived
```

Rider:

``` text
New offer
Offer expired
Delivery assigned
Pickup reminder
```

## Completion

-   [x] FCM (ready — `FCM_SERVER_KEY` env var enables FCM mode)
-   [x] Notification persistence (`notifications` table in `taladelivery_notification`)
-   [x] Retries (via `EventWorkerManager` with backoff)
-   [x] Read/unread (`isRead`, `readAt` fields + `markAsRead` method)
-   [x] Event consumers (`NotificationConsumer` listens to `notification-jobs` queue)

------------------------------------------------------------------------

# Phase 12 --- Complete App Testing

Now test the entire system using NestJS.

-   [x] Automated end-to-end flow (`test/e2e-flow.mjs`), 23 assertions
-   [x] Rider / broker flow (`test/rider-flow.mjs`), 46 assertions
-   [x] Customer journey: register, login, browse, order, track, list
-   [x] Merchant journey: login, confirm, preparing, ready for pickup
-   [x] Rider journey: register → admin approval → online → offer → accept →
      arrived → pickup → in transit → deliver
-   [x] Authorization boundaries verified (customer cannot drive merchant
      transitions; pending rider cannot go online; spent offer cannot be
      re-accepted)
-   [x] Admin dashboard aggregate returns real cross-service totals
-   [x] Cross-service event fan-out: `order.ready_for_pickup` → matching →
      offer; `delivery.*` → order FSM; `payment.*` → order + notifications
-   [x] Customer and merchant notification delivery
-   [x] Every queue drains to zero with no failed and no discarded jobs

## Customer

``` text
Login
↓
Browse
↓
Order
↓
Track
↓
Receive
```

## Merchant

``` text
Login
↓
Receive Order
↓
Confirm
↓
Prepare
↓
Ready
```

## Rider

``` text
Login
↓
Online
↓
Receive Offer
↓
Accept
↓
Pickup
↓
Deliver
```

## Admin

``` text
Dashboard
↓
Orders
↓
Merchants
↓
Riders
↓
Deliveries
↓
Manual Intervention
```

## Phase 12 Results

Two automated flows against the eight live services
(`scripts/start-dev.ps1`, Redis required):

| Suite | Assertions | Result |
|-------|-----------|--------|
| `test/e2e-flow.mjs` — customer, merchant, admin | 23 | **23 passed, 0 failed** |
| `test/rider-flow.mjs` — rider lifecycle, event fan-out, notifications | 48 | **48 passed, 0 failed** |
| `test/admin-merchant-flow.mjs` — role-scoped feeds, admin alerts, realtime fan-out | 33 | **33 passed, 0 failed** |
| `npm run test:all` — unit | 108 | **108 passed, 0 failed** |
| `npm run typecheck` — 9 projects | — | clean |

Covered end to end:

-   Health probe, all 8 services.
-   Customer: register, login, browse stores/products, create order, list
      orders, read notifications.
-   Merchant: login, confirm → preparing → ready for pickup, receive
      "new order" notification.
-   Rider: register, blocked while pending, admin approval, go online,
      location, receive offer, accept (and cannot re-accept), arrived →
      pickup → start → complete.
-   Event fan-out: `order.ready_for_pickup` → dispatch matching → offer;
      `delivery.*` → order FSM reaches `DELIVERED` with **no direct HTTP call**
      from the test; `payment.*` → order `paymentStatus = PAID`.
-   Zone pricing applied (`deliveryFee 49.00` from the seeded Makati zone).
-   Admin dashboard aggregate across all services.
-   Admin: a rider application alerts every platform admin (notification in
      the `admin.*` namespace) and emits `rider.application` to
      `admin:platform`.
-   Role scoping: store admin and customer are both refused
      `/admin/notifications`; customer is refused `/merchant/notifications`;
      a notification belonging to someone else cannot be marked read.
-   Merchant hears the full order lifecycle (`order.received`,
      `order.cancelled`, `order.delivered`), not just creation.
-   All nine queues drain to zero: no failed jobs, no unroutable jobs.

### Notification and realtime surfaces

| Endpoint | Role | Notes |
|----------|------|-------|
| `GET /notifications` | any | Per-user feed, paginated, snake_case. |
| `POST /notifications/:id/read` | any | Idempotent; another user's id returns 404, not 403. |
| `POST /notifications/read-all` | any | Bulk mark-read. |
| `GET /admin/notifications` | platform admin | All `admin.*` notifications across admins, with `unread` and `by_type` in `meta`. |
| `GET /merchant/notifications` | store admin | Every member of the caller's store, with `unread` and the store in `meta`. |

Both scoped feeds derive their scope **from the token**, never from a query
parameter, so a store admin cannot widen their scope by editing the URL. The
merchant feed resolves the caller's store through
`GET /internal/stores/by-user/:userId` (an array — a user may belong to more
than one store; the first is used) and then
`GET /internal/stores/:id/store-users` for the member ids.

WebSocket rooms and their authorization are in §20.15 / §20.14.2.
`realtime.emit` on `realtime-feed` is how non-gateway services push to rooms.

### Bugs found and fixed during Phase 12

**Correctness**

-   **Events were silently destroyed by competing consumers.** 11 orders
    produced 6 payment records. `order-events` and `delivery-events` each had
    two consumer processes filtering by `eventTypes`; BullMQ gives a job to
    one worker, which then discarded anything it did not want. Fixed by
    enforcing one consumer per queue and fanning out at publish. See
    §20.14.1.
-   **Two consumers read the wrong handler argument.**
    `EventWorkerManager` calls `handler(envelope.data, envelope, ctx)`, but
    order-service and notification-service read `event.data` from the *first*
    argument. In notification-service that silently picked up the payload's
    inner `data` blob, so every insert violated the not-null constraint on
    `notifications.user_id`; in order-service it yielded `undefined`, so
    **no delivery event ever moved an order**. Both consumers now use the
    documented contract.
-   **Only the first registration per queue was ever served.**
    `ensureWorker` captured the registration in a closure, so a later `on()`
    for the same queue updated the map but the worker kept the old handler.
    Registrations are now retained and dispatched by first match.
-   **The realtime gateway accepted refresh tokens as access tokens.** It
    called `jwt.verifyAsync` directly instead of
    `TokenService.verifyAccess`, which also checks the token `type`. It also
    had no `JwtService` provider and declared a `JWT_SECRET` read by nothing,
    so the gateway had never actually booted.
-   **"Insufficient stock" returned 500.** Upstream 4xx from
    catalog/dispatch/merchant escaped `ServiceCallError` uncaught, so
    customer-actionable failures (stock, closed store, out-of-zone address)
    looked like server faults. Now translated to 422; genuine 5xx still 500.

**Configuration**

-   **Order creation hung forever with no error.** `EventPublisher` awaited
    `queue.add()`; BullMQ's ioredis buffers commands while offline, so with
    no Redis the promise never settled. Bounded by
    `EVENTS_PUBLISH_TIMEOUT_MS` with fail-soft. See §20.6.2.
-   **`GET /admin/dashboard` returned 500.** `JWT_ACCESS_SECRET` was
    undeclared in dispatch/payment/notification env schemas and
    `createEnvValidator` strips undeclared keys, so `getOrThrow()` threw
    mid-request. See §20.6.1.
-   **notification-service silently used `localhost:6379`** because it
    declared no `REDIS_*` at all; order-service and realtime-service declared
    only host/port. All now declare the full set.
-   **A global `POSTGRES_DB_NAME` in `.env` pointed every service at one
    database.** See §20.6.1.

**Observability and process**

-   **Dashboard reported `orders: 0`.** `adminTotals()` used removed
    TypeORM 0.2 `{ $gte, $lt }` range syntax behind an `as never` cast. Fixed
    with `Between()`; the dashboard's silent `catch` had been hiding it, so
    those fallbacks now log. See §20.9.1.
-   **The dashboard's silent `catch` masked the above** — a broken aggregate
    looked identical to an empty platform.
-   **Rider onboarding had no API at all** despite "read/unread" being marked
    complete: `listForUser`/`markAsRead` existed but no controller exposed
    them. Added `GET /notifications`, `POST /notifications/:id/read`,
    `POST /notifications/read-all`.
-   **`payment-events` and `location-events` had publishers but no
    consumers.** Added order-service's `PaymentEventsConsumer` (mirrors
    payment state and notifies the customer) and realtime-service's
    `LocationEventsConsumer` (broadcasts rider position to Socket.IO rooms).
-   **Dead publishes removed:** `dispatch.offer_created`,
    `dispatch.rider_assigned` and `dispatch.offer_expired` were published to
    `delivery-events`, which order-service owns and cannot handle — pure
    job destruction. The offer row and the re-match are the whole effect.
-   **`nest build` passed while `ts-node` failed at boot** on the same file.
    Use `npm run typecheck`.

### Tooling added

| Script | Purpose |
|--------|---------|
| `scripts/start-dev.ps1` | Start all 9 services, per-service DB, logs to `.logs/`, health-probe loop. Realtime (port 3008) is included by default; pass `-NoRealtime` to skip it. See `docs/RUNNING-AND-REALTIME.md`. |
| `scripts/stop-dev.ps1` | Free the service ports. |
| `test/e2e-flow.mjs` | Customer / merchant / admin flow (23). |
| `test/rider-flow.mjs` | Rider lifecycle, event fan-out, notifications (48). |
| `test/admin-merchant-flow.mjs` | Role-scoped feeds, admin alerts, realtime fan-out (33). |
| `test/reset-fixtures.mjs` | Restore product stock and clear stale offers/riders so runs are repeatable. |
| `test/inspect-queues.mjs` | Per-queue waiting/active/failed/delayed counts — the fastest way to spot event loss. |
| `test/ensure-databases.mjs` | Create any missing `taladelivery_*` database. |

### Test accounts

| Role | Email | Password |
|------|-------|----------|
| Platform admin | `admin@taladelivery.com` | `Admin@123456` |
| Store admin | `storeadmin@test.com` | `Store@123456` |

Seeded fixtures: store 1 "Test Store", product 1 "Test Product 1" (99.00),
delivery zone 1 "Makati Zone". Riders and customers are created per run.

### Known gaps

-   **No transactional outbox.** An event published after the database
    commit is lost if the process dies in between. §20.13 remains open; the
    broker fail-soft path widens this window.
-   **Riders are not notified of a new offer.** `dispatch.offer_created` has
    no consumer; realtime push for riders is not wired up. A rider only
    learns of an offer by polling `GET /rider/offers`.
-   **`order.confirmed` / `order.preparing`** reach only the customer's
    notification feed; no service acts on them.
-   **Realtime gateway has no integration test.** It boots and consumes
    `location-events` and `realtime-feed`, and the `admin:` room is
    authorized, but no test drives a live Socket.IO client. The queue-level
    fan-out is verified; the socket delivery is not.
-   **Notification FCM delivery is a stub.** `NotificationService.health()`
    reports `mode: 'stub'` because `FCM_SERVER_KEY` is unset; push to a real
    device is untested.


------------------------------------------------------------------------

# Phase 13 --- Laravel vs NestJS Validation

Run equivalent scenarios against both implementations.

``` text
                Laravel       NestJS

Register          ✓             ✓
Login             ✓             ✓
Browse            ✓             ✓
Order             ✓             ✓
Confirm           ✓             ✓
Prepare           ✓             ✓
Ready             ✓             ✓
Match Rider       ✓             ✓
Accept            ✓             ✓
Pickup            ✓             ✓
Deliver           ✓             ✓
Cancel            ✓             ✓
Pricing           ✓             ✓
Commission        ✓             ✓
```

Do not cut over until critical behavior matches or intentional
differences are documented.

------------------------------------------------------------------------

# Phase 14 --- NestJS Staging

Create:

``` text
staging-api.delivery.tala-works.online
staging-ws.delivery.tala-works.online
```

Staging should resemble production.

Test:

-   [ ] Docker deployment
-   [ ] Gateway
-   [ ] databases
-   [ ] Redis
-   [ ] queues
-   [ ] WebSockets
-   [ ] concurrent orders
-   [ ] concurrent rider acceptance
-   [ ] disconnect/reconnect
-   [ ] service restart
-   [ ] Redis restart/recovery strategy
-   [ ] DB backup/restore
-   [ ] malformed requests
-   [ ] authentication expiration
-   [ ] duplicate events
-   [ ] duplicate payment requests

------------------------------------------------------------------------

# Phase 15 --- Data Migration

Source:

``` text
Laravel
tala_delivery
```

Destination:

``` text
NestJS

identity_db
merchant_db
catalog_db
order_db
dispatch_db
payment_db
notification_db
```

Recommended order:

``` text
Users
 ↓
Merchants
 ↓
Catalog
 ↓
Orders
 ↓
Riders
 ↓
Deliveries
 ↓
Notifications
 ↓
Payments
```

Preserve IDs where practical.

Validate:

``` text
row counts
order totals
order items
delivery assignments
user roles
merchant relationships
rider relationships
payment values
```

Never migrate blindly.

------------------------------------------------------------------------

# Phase 16 --- Production Cutover

Before:

``` text
Flutter/Angular
      ↓
Laravel
```

After:

``` text
Flutter/Angular
      ↓
NestJS Gateway
      ↓
Microservices
```

Switch:

``` text
api.delivery.tala-works.online
```

to NestJS.

And:

``` text
ws.delivery.tala-works.online
```

to Realtime Service.

Monitor:

``` text
Gateway
Orders
Dispatch
Payments
Redis
BullMQ
WebSockets
PostgreSQL
Notifications
```

------------------------------------------------------------------------

# Phase 17 --- Laravel Rollback Period

Do NOT delete Laravel immediately.

Keep:

``` text
Laravel repository
Laravel Docker image
Laravel environment backup
Old PostgreSQL backup
Migration scripts
```

Laravel should no longer receive normal production writes.

Use it only as:

``` text
Reference
+
Emergency rollback asset
```

------------------------------------------------------------------------

# Phase 18 --- Retire Laravel

After NestJS has been stable for an agreed observation period:

-   [ ] Confirm no application calls Laravel
-   [ ] Confirm all production data is in NestJS-owned databases
-   [ ] Final Laravel DB backup
-   [ ] Final source tag
-   [ ] Archive repository
-   [ ] Disable Laravel deployment
-   [ ] Remove Laravel infrastructure
-   [ ] Keep backups according to retention policy

Final:

``` text
Customer Flutter ───┐
Rider Flutter ──────┤
Merchant Angular ───┼──► NestJS API Gateway
Admin Angular ──────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
            Orders      Dispatch     Payment
              │            │            │
              └────── Events/Redis ─────┘
                           │
                    Realtime + FCM
```

Laravel is now retired.

------------------------------------------------------------------------

# Phase 19 --- Future TalaDelivery Expansion

Only after the delivery platform is stable should TalaDelivery expand
toward the broader logistics/transport vision.

Possible products:

``` text
TalaDelivery
│
├── Store Delivery
├── Food Delivery
├── Pabili
├── Parcel/Courier
├── Same-Day Delivery
├── Motorcycle Ride
├── Car Ride
└── Business Logistics
```

Do not create a separate backend for each product.

Reuse platform services.

Future additions:

``` text
booking-service
pricing-service
location-service
earnings-service
```

Architecture:

``` text
                    TalaDelivery Platform
                            │
                        API Gateway
                            │
          ┌─────────────────┼─────────────────┐
          ▼                 ▼                 ▼
       Delivery           Courier            Ride
        Orders            Booking           Booking
          │                 │                 │
          └─────────────────┼─────────────────┘
                            ▼
                         Dispatch
                            │
                    ┌───────┼───────┐
                    ▼       ▼       ▼
                  Rider   Driver  Courier
                            │
                            ▼
                        Location
                            │
                            ▼
                         Realtime
```

The shared services remain:

``` text
Identity
Merchant
Catalog
Payment
Dispatch
Location
Pricing
Notification
Realtime
```

------------------------------------------------------------------------

# Final Development Rule

For every feature during migration:

``` text
1. Make/verify process in Laravel
              ↓
2. Confirm expected behavior
              ↓
3. Document business rules
              ↓
4. Implement in NestJS owner service
              ↓
5. Add automated tests
              ↓
6. Compare behavior
              ↓
7. Test through Flutter/Angular
              ↓
8. Mark NestJS feature complete
```

Do not blindly translate:

``` text
Laravel Controller
        ↓
NestJS Controller
```

Instead translate:

``` text
BUSINESS PROCESS
        ↓
DOMAIN OWNER
        ↓
NestJS Service
        ↓
Database
        ↓
Events
        ↓
Other Services
```

------------------------------------------------------------------------

------------------------------------------------------------------------

# 20. NestJS Engineering Standards

This section is mandatory for the new TalaDelivery NestJS
implementation. The existing roadmap already defines a NestJS monorepo,
service-owned databases, Redis/BullMQ, API Gateway, validation, health
checks, and service boundaries. The rules below define the coding and
production standard every service must follow.

## 20.1 Runtime and Workspace

-   Use the project-approved current NestJS major version and pin
    dependencies.
-   Use a supported Node.js LTS version and pin it for local
    development, CI, and Docker.
-   Use TypeScript with `strict: true`.
-   Prefer ESM for a new project unless a required dependency prevents
    it.
-   Commit the package lockfile and use reproducible installs in CI.
-   Use NestJS monorepo/workspace mode for TalaDelivery's multiple
    applications and shared libraries.
-   Every app under `apps/` must remain independently buildable and
    deployable.

``` text
taladelivery-backend/
├── apps/
│   ├── api-gateway/
│   ├── identity-service/
│   ├── merchant-service/
│   ├── catalog-service/
│   ├── order-service/
│   ├── dispatch-service/
│   ├── payment-service/
│   ├── notification-service/
│   └── realtime-service/
├── libs/
│   ├── contracts/
│   ├── events/
│   ├── auth/
│   ├── common/
│   └── observability/
├── docker/
├── nest-cli.json
├── package.json
├── tsconfig.json
└── docker-compose.yml
```

## 20.2 Standard NestJS Responsibility Flow

``` text
Controller / Message Handler
            ↓
Application Service / Use Case
            ↓
Domain Rules
            ↓
Repository / External Port
            ↓
Infrastructure Adapter
            ↓
PostgreSQL / Redis / External API
```

Rules:

-   Controllers stay thin.
-   Controllers handle transport concerns and delegate business work to
    providers.
-   Business rules belong in injectable services/use cases/domain code.
-   Database access belongs behind repository/data-access providers.
-   Prefer constructor dependency injection.
-   Use modules to create explicit feature boundaries.
-   Guards handle authentication/authorization.
-   Pipes handle validation/transformation.
-   Interceptors handle cross-cutting request/response behavior.
-   Exception filters map internal errors into safe transport errors.
-   Avoid circular dependencies and do not use `forwardRef()` to hide
    poor boundaries.
-   Follow SOLID principles.

## 20.3 Feature Structure

Organize each service by business feature, not one giant global
`controllers/`, `services/`, and `repositories/` folder.

``` text
apps/order-service/src/
├── main.ts
├── app.module.ts
├── orders/
│   ├── orders.module.ts
│   ├── presentation/
│   │   ├── orders.controller.ts
│   │   └── dto/
│   ├── application/
│   │   ├── create-order.service.ts
│   │   ├── cancel-order.service.ts
│   │   └── ports/
│   ├── domain/
│   │   ├── order.entity.ts
│   │   ├── order-status.enum.ts
│   │   ├── order.errors.ts
│   │   └── events/
│   └── infrastructure/
│       ├── persistence/
│       ├── messaging/
│       └── clients/
├── config/
└── health/
```

Keep small features simple; do not create unnecessary abstraction merely
to satisfy a folder pattern.

## 20.4 Module Standard

-   Every business capability has a NestJS module.
-   Keep module public APIs small.
-   Export only providers genuinely needed outside the module.
-   Do not create a giant `SharedModule` containing unrelated domain
    behavior.
-   Shared libraries may contain contracts and cross-cutting
    infrastructure, but not ownership of another service's business
    logic.
-   Never import another microservice's ORM entities or repositories.

## 20.5 DTO and Validation Standard

Every external input requires an explicit DTO/schema and validation.

Validate:

``` text
HTTP requests
WebSocket messages
queue/message payloads
webhooks
environment configuration
```

Rules:

-   Never accept ORM entities directly as request DTOs.
-   Whitelist allowed properties and reject unexpected input for
    security-sensitive commands.
-   Do not trust client-provided price, total, role, ownership, payment
    success, or rider assignment.
-   Authoritative totals and state transitions are calculated
    server-side.
-   Request DTOs, domain models, persistence models, and response
    contracts may be separate when responsibilities differ.

### 20.5.1 `whitelist: true` strips any property with no validation decorator

`laravelValidationPipe()` runs with `whitelist: true` (see
`libs/common/src/validation.ts`). class-validator's whitelist removes every
property that carries **no** validation decorator, silently. `@Type()` from
`class-transformer` is not a validation decorator, so a nested object declared
as:

``` ts
// BROKEN: `zone` is stripped and arrives as undefined
@Type(() => ZonePricingInputDto)
zone: ZonePricingInputDto;
```

reaches the handler as `undefined` and the endpoint fails with a 500 far from
the real cause. A nested property must be registered *and* validated:

``` ts
@IsObject()
@ValidateNested()
@Type(() => ZonePricingInputDto)
zone: ZonePricingInputDto;
```

`@Type(() => Number)` on a scalar is fine as long as the property also has
`@IsInt()` / `@IsNumber()`.

Regression check: `test/zone-preview-pipe-check.ts` runs the real pipe over a
preview payload and asserts `dto.zone` survives as a `ZonePricingInputDto`.

### 20.5.2 Decimal fields are strings on the wire, in both directions

Laravel decimal casts serialize as strings, so every money/distance/coordinate
DTO field is `@IsString() @Matches(/^(0|[1-9]\d*)(\.\d+)?$/)` — defined once as
`NUMERIC_STRING` in `apps/dispatch-service/src/dto/delivery-zone.dto.ts`.
`transformOptions.enableImplicitConversion` is `false`, so nothing coerces
implicitly.

Consequences for the Angular clients:

- **Writes** must send decimal **strings**. Sending JSON numbers returns
  `422 "base_fee must be a string"` and the save silently never happens. Zone
  create/update *and* pricing preview share this rule; `ZoneListComponent`
  formats at the boundary via `decimal()` / `optionalDecimal()`.
- **Reads** return decimal strings too (`"base_fee":"49.00"`). The read model
  stays `number`-typed and `ZoneService.toZone()` coerces, so templates,
  sorting and `CurrencyPipe` keep working.

Keep a separate write type (`DeliveryZoneWrite`) from the read model
(`DeliveryZone`) so the two shapes cannot drift into each other.

## 20.6 Configuration Standard

Use centralized typed configuration.

``` text
ConfigModule
├── app
├── database
├── redis
├── jwt
├── queue
├── websocket
└── providers
```

-   Validate environment variables at startup.
-   Fail startup when required configuration is missing/invalid.
-   Do not scatter `process.env` access through business code.
-   Never commit secrets.
-   Separate development, test, staging, and production configuration.

### 20.6.1 Env schema is an allow-list

`createEnvValidator()` runs each service's schema with `whitelist: true`
(§`libs/common/src/env.ts`). Consequences that have caused real outages:

-   **Any variable a service reads must be declared in its schema.**
    Undeclared keys are silently stripped from the validated config, so
    `config.get('JWT_ACCESS_SECRET')` returns `undefined` and a
    `getOrThrow()` deeper in the request fails at runtime --- not at boot.
    When adding a service-wide setting (JWT, queue, broker) to `.env`, add
    it to **every** service's `config/env.ts`.
-   **Do not put `POSTGRES_DB_NAME` in `.env`.** It is a per-service
    override, not a shared default. A single global value silently points
    every service at one database, and with `synchronize: true` in
    development it will cheerfully create foreign tables there. Leave it
    unset and let each service fall back to its own `*_DB_NAME` constant,
    or set the variable per-process (see `scripts/start-dev.ps1`).

### 20.6.2 Broker unavailability must not hang requests

BullMQ's ioredis client has `enableOfflineQueue: true` by default, so with
Redis down a `queue.add()` never resolves --- it buffers the command until
reconnect. Every `await events.publish(...)` therefore hangs the HTTP
request that triggered it, with no exception and no log line. The failure
looks like a slow endpoint, not a missing broker.

`EventPublisher` (and therefore every publisher, including
`OfferExpiryScheduler`) prevents this:

-   Queues are created with `maxRetriesPerRequest: 1` so `add()` rejects
    instead of waiting.
-   Each enqueue is bounded by `EVENTS_PUBLISH_TIMEOUT_MS` (default 2000).
-   When the broker is unreachable the job is dropped with a warning while
      `EVENTS_FAIL_SOFT` is not `false` (the default outside production).
      Set `EVENTS_FAIL_SOFT=false` to make it throw instead.
-   Consumers keep retrying; their `error` events are logged once per
    attempt by `EventWorkerManager` instead of surfacing as unhandled
    ioredis errors.

Fail-soft is a resilience measure for local/dev and for broker outages, not
a durability guarantee. Production must run Redis, and the eventual
correctness path is a transactional outbox so an enqueue cannot be lost
between the database commit and the queue write.

Run the local stack with `scripts/start-dev.ps1` (one process per service,
per-service `POSTGRES_DB_NAME`, logs in `.logs/`); `scripts/stop-dev.ps1`
frees the ports. The script starts services with a 4s stagger because each is
a separate `ts-node` process; launching all nine at once exhausts memory and
kills the last one with `Zone Allocation failed - process out of memory`.
Realtime (port 3008, database `taladelivery_realtime`) is started by default;
pass `-NoRealtime` to skip it. Full runbook: `docs/RUNNING-AND-REALTIME.md`.

`npm run build` is not a sufficient check — it has been observed to pass while
`ts-node` fails at boot on the same file. Use `npm run typecheck`, which
type-checks all nine projects with the same tsconfig the services run under.

## 20.7 API Standard

Public API:

``` text
/api/v1/...
```

Required:

-   API versioning
-   Swagger/OpenAPI
-   consistent status codes
-   pagination for collections
-   correlation/request ID
-   rate limiting where appropriate
-   idempotency keys for sensitive create/payment operations
-   stable machine-readable error codes

Example:

``` json
{
  "statusCode": 409,
  "code": "ORDER_INVALID_STATE",
  "message": "Order cannot transition to READY_FOR_PICKUP.",
  "requestId": "..."
}
```

Never expose stack traces, SQL errors, internal hostnames, or secrets to
clients.

## 20.8 API Gateway Standard

The API Gateway handles:

``` text
public routing
authentication verification
rate limiting
API versioning
correlation IDs
request-level observability
```

It must not become the business layer. Order transitions, rider
assignment, pricing, payment decisions, and merchant rules belong to
their owning services.

### 20.8.1 Angular client: do not bundle mapbox-gl

The gateway is the only entry point for both Angular apps, and
`/broadcasting` (Laravel Echo) no longer exists — the admin and merchant apps
talk to `realtime-service` over Socket.IO through the dev proxy.

`mapbox-gl` must stay **outside** the Angular bundler, in both apps.

Angular's esbuild pipeline force-disables the `object-rest-spread` language
feature in `getFeatureSupport()` (`@angular/build/src/tools/esbuild/utils.js`).
This is a deliberate V8 performance workaround
([crbug.com/11536](https://bugs.chromium.org/p/v8/issues/detail?id=11536)) and
is **not** configurable — browserslist and the build `target` do not affect it.
Any bundled mapbox code is therefore rewritten to call `__spreadValues` /
`__spreadProps`.

The main thread survives this: esbuild hoists the helpers into a shared chunk
and emits an `import` for them. mapbox-gl v3 does not. It builds its tile
worker by stringifying its own bundled code into a `Blob`, and stringification
drops the `import` while keeping the calls, so the worker throws

``` text
ReferenceError: __spreadValues is not defined
```

on every tile. The map then renders permanently blank, drawing silently does
nothing, and nothing appears in the UI — only in the console.

Setup (already applied to `talaDelivery-admin`):

1. `scripts/sync-mapbox-gl.mjs` copies `node_modules/mapbox-gl/dist/mapbox-gl.js`
   to `public/vendor/mapbox-gl.js`. It runs from `postinstall` and can be
   re-run with `npm run sync:mapbox`.
2. `src/index.html` loads it before the app bundle:
   `<script src="vendor/mapbox-gl.js"></script>`
3. Components obtain the API through `core/mapbox/mapbox-global.ts`, which
   reads `window.mapboxgl` and throws a named error if the script did not load.
   `import type` is still fine for types — it is erased at build time.
4. `mapbox-gl/dist/mapbox-gl.css` is `@import`ed at the top of `src/styles.css`
   — **not** added to the `styles` array in `angular.json`.

### 20.8.2 Why the Mapbox CSS must be an `@import` in `styles.css`

`ng build` honours multiple entries in the `styles` array, but `ng serve` only
emits the **first** entry as a `<link>`. Putting `mapbox-gl.css` in that array
therefore yields a production build that works and a dev server that silently
ships none of it.

The failure is subtle and misattributes itself. Without the stylesheet:

- `.mapboxgl-map` never gets `overflow: hidden`, so the absolutely positioned
  attribution and logo controls spill out of the 320px map container and cover
  the buttons rendered beneath it. It looks like a z-index or wiring bug.
- `.mapboxgl-ctrl-attrib` has no positioning, so `compact: true` has no effect
  and the full "© Mapbox © OpenStreetMap / Improve this map" strip shows.
- Tiles still render, because canvas sizing comes from the container rather than
  the stylesheet — so the map looks alive and only the controls are wrong.

The library loads fine over a plain `<script>`, so this only shows up in the
**dev** stylesheet. Check that, not the built one:

``` powershell
(Invoke-WebRequest http://localhost:4200/styles.css).Content -match '\.mapboxgl-map\s*\{[^}]*overflow:\s*hidden'
```

Keep Mapbox's own overlays clear of interactive UI. The logo and attribution are
pinned to the bottom corners of the canvas, so the drawing controls belong
**above** the map, not below it.

Attribution is required by the Mapbox terms of service and must stay visible.
`AttributionControl({ compact: true })` collapses it to a badge that expands on
click. Note the `Map` option `attributionControl` is typed as a plain boolean
and cannot carry the flag, so the control must be added explicitly, and
Mapbox's `_updateCompact()` strips the compact class above 640px, so it needs
re-asserting on `resize`.

Do **not** serve the library with an `angular.json` `assets` entry pointing at
`node_modules`. `ng build` honours it, but the dev server only reads
`angular.json` at startup, so the asset stays 404 (masked by the SPA fallback,
which returns `index.html` and trips strict MIME checking) until the dev server
is restarted. `public/` is the right place: the existing `"input": "public"`
glob already covers it, and `ng build` emits `vendor/mapbox-gl.js` unchanged.

Adding any *new* file under `public/` also needs a dev-server restart — the
asset list is snapshotted at startup even though later edits to existing files
are picked up live.

Verify after touching this: `ng build --configuration development` must show no
`mapboxgl.workerUrl` / `mapboxgl-canvas` in any app chunk, and
`vendor/mapbox-gl.js` must contain zero `__spreadValues` references.

## 20.9 Database Standard

Each service owns its database.

``` text
identity-service     → taladelivery_identity
merchant-service     → taladelivery_merchant
catalog-service      → taladelivery_catalog
order-service        → taladelivery_order
dispatch-service     → taladelivery_dispatch
payment-service      → taladelivery_payment
notification-service → taladelivery_notification
```

Rules:

-   No cross-service SQL joins.
-   No cross-service foreign keys.
-   No service directly writes another service's tables.
-   Migrations belong to the owning service.
-   Use local database transactions for atomic operations.
-   Use explicit indexes for important query paths.
-   Never use floating point for money.
-   Store timestamps consistently in UTC and convert for presentation.
-   Historical order/payment snapshots must remain immutable where
    required.

### 20.9.1 TypeORM `find` operators — no `as never`

TypeORM 0.3 removed the 0.2 comparison-object syntax. A range must be
written with `Between()`:

``` text
WRONG  where: { createdAt: { $gte: start, $lt: end } }
RIGHT  where: { createdAt: Between(start, end) }
```

The wrong form is not a no-op: the object is serialized as a single
parameter value, so Postgres raises

``` text
invalid input syntax for type timestamp with time zone: "{"$gte":...}"
```

and the whole query fails. Because `FindOptionsWhere` rejects that shape,
the mistake is usually "fixed" with an `as never` cast, which silences the
compiler and ships the broken query. Ban `as never` on `where` clauses and
use `Between` / `MoreThan` / `In` / `Raw`. Run `npm run typecheck`, which
type-checks all nine projects, not just `nest build` --- the Nest build has
been observed to pass while `ts-node` fails at boot on the same file.

## 20.10 Schema Migration Standard

Do not use automatic schema synchronization in production.

Every schema change must have a reviewed migration.

Prefer:

``` text
Backward-compatible DB migration
        ↓
Deploy compatible application
        ↓
Migrate/backfill data
        ↓
Remove obsolete schema in a later release
```

Do not combine a destructive schema change with the first release that
depends on its replacement.

## 20.11 Communication Standard

Use synchronous communication when an immediate answer is required.

Use asynchronous events for independent reactions.

``` text
COMMANDS
CreateOrder
AcceptDeliveryOffer
CapturePayment

EVENTS
order.created
order.ready_for_pickup
dispatch.rider_assigned
payment.paid
delivery.delivered
```

Rules:

-   Commands express intent.
-   Events describe facts that already happened.
-   Event names use past tense.
-   Every event has a stable contract/version.
-   Include event ID, occurred-at timestamp, correlation/trace ID, and
    relevant aggregate IDs.
-   Consumers must be idempotent.
-   Synchronous calls require explicit timeouts.
-   Avoid long synchronous service-call chains.

## 20.12 Standard Event Envelope

``` json
{
  "eventId": "uuid",
  "eventType": "order.ready_for_pickup",
  "eventVersion": 1,
  "occurredAt": "2026-09-29T07:00:00Z",
  "correlationId": "uuid",
  "data": {
    "orderId": "uuid",
    "merchantId": "uuid"
  }
}
```

Do not publish entire database entities merely because it is convenient.

## 20.13 Reliable Events / Transactional Outbox

For critical state changes:

``` text
BEGIN LOCAL TRANSACTION
  update business state
  insert outbox event
COMMIT
        ↓
Outbox Publisher
        ↓
Queue/Broker
        ↓
Consumer
        ↓
Idempotency Check
```

Use the transactional outbox pattern when losing an event could create
inconsistent business state.

## 20.14 Redis and BullMQ Standard

Redis/BullMQ may handle:

-   asynchronous jobs
-   delivery-offer expiry
-   notification jobs
-   retries
-   delayed jobs
-   background work

Rules:

-   Queue/job names are explicit.
-   Critical jobs are idempotent.
-   Configure bounded retries and backoff deliberately.
-   Failed/stalled jobs are observable.
-   Configure completed/failed job retention.
-   Redis is not the permanent source of truth for orders, deliveries,
    or payments.
-   **One consumer process per queue.** See §20.14.1.

### 20.14.1 One consumer per queue — `eventTypes` is not routing

BullMQ hands a claimed job to exactly **one** worker. `EventWorkerManager`
filters by `eventTypes` *after* claiming, so a worker that does not want a job
discards it. Two services consuming one queue therefore do not "each take the
events they care about" — they destroy roughly half of everything between
them, silently, with no failed job to show for it.

Observed during Phase 12: 11 orders created, 6 payment records. `payment.paid`
and `order.created` were being claimed at random by dispatch's worker, which
has no handler for them.

Two rules follow:

1.  A queue is owned by exactly one service. When a second service needs the
    same event, the **publisher fans out** to that service's own queue.
2.  Do not publish an event to a queue whose owner has no handler for it.
    That is a job created only to be destroyed.

`EventWorkerManager` now logs a warning when it discards an unroutable event,
so violations are visible instead of silent.

Current topology:

| Queue | Publisher | Consumer |
|-------|-----------|----------|
| `order-events` | order-service | dispatch (`ready_for_pickup`, `cancelled` only) |
| `delivery-events` | dispatch | order-service |
| `payment-events` | payment-service | order-service (mirrors payment state) |
| `payment-jobs` | order-service, dispatch | payment-service |
| `merchant-jobs` | order-service | merchant-service |
| `notification-jobs` | any service | notification-service |
| `offer-expiry` | dispatch | dispatch |
| `location-events` | dispatch | realtime-service |
| `realtime-feed` | any service | realtime-service (Socket.IO fan-out) |

`payment-jobs` and `merchant-jobs` are named for the *subscriber*, not the
event domain, because the subscriber is what makes them a distinct queue.
`payment-events` (payment's outbound) and `payment-jobs` (payment's inbound)
must stay separate, or payment would consume its own events.

### 20.14.2 Realtime fan-out via `realtime-feed`

A Socket.IO client cannot subscribe to a queue, so services that need to push
to a room publish `realtime.emit` to `realtime-feed` instead:

``` json
{
  "rooms": ["merchant:1", "order:42", "customer:7", "user:7"],
  "event": "order.updated",
  "data": { "orderId": 42, "status": "PREPARING" }
}
```

The **publisher names the audience**. `RealtimeFeedConsumer` only emits; it
never decides who may see what, so routing cannot drift from authorization.
Room authorization still happens at subscribe time in
`RealtimeGateway.canSubscribe`.

Rooms: `user:<id>` (own only), `order:<id>`, `customer:<id>`,
`merchant:<id>` and `rider:<id>` (own role or platform admin), and
`admin:platform` (platform admin only).

| Event | Rooms | Emitter |
|-------|-------|---------|
| `order.updated` | `order:<id>`, `user:<customer>`, `customer:<customer>`, `merchant:<store>` | order-service |
| `rider.location` | `order:<deliveryId>`, `rider:<riderId>` | realtime-service, from `location-events` |
| `rider.application` | `admin:platform` | identity-service |

## 20.15 WebSocket Standard

WebSocket is a transport, not a second business backend.

Inbound:

``` text
Client
  ↓
WebSocket Gateway
  ↓
Authentication + Validation
  ↓
Owning Application Service
```

Outbound:

``` text
Committed Domain Event
  ↓
Realtime Service
  ↓
Authorized Room
  ↓
Client
```

-   Authenticate connections.
-   Authorize room subscriptions.
-   Validate payloads.
-   Apply sensible connection/event limits.
-   Support reconnects.
-   Never trust client-supplied ownership.
-   Important state remains in the owning service/database.

## 20.16 Rider Location Standard

Current rider location is high-frequency ephemeral data.

``` text
Rider Flutter
     ↓
Location/Realtime endpoint
     ↓
Redis GEO/current state
     ├── Dispatch
     └── Customer tracking
```

Persist only the location history required by product, operations,
audit, safety, or analytics requirements. Do not write every GPS packet
into the primary rider/order tables.

## 20.17 Security Standard

Required:

-   JWT access tokens
-   refresh-token rotation
-   secure password hashing
-   RBAC/permission guards
-   resource ownership checks
-   rate limiting
-   CORS allowlist
-   secure HTTP headers
-   DTO validation
-   webhook signature verification
-   service-to-service authentication
-   secrets outside source control
-   audit logging for sensitive admin/payment actions

Never log passwords, access tokens, refresh tokens, payment secrets, or
provider secrets.

## 20.18 Payment Standard

-   Payment Service is authoritative for payment state.
-   Use idempotency keys.
-   Verify provider webhook signatures.
-   Store provider event IDs.
-   Reject duplicate webhook processing.
-   Never trust a client to report successful payment.
-   Maintain auditable payment transitions.
-   Order Service receives payment changes through defined API/event
    contracts.

## 20.19 Logging and Observability Standard

Use structured JSON logs.

Include where applicable:

``` text
timestamp
level
service
environment
requestId
correlationId
traceId
userId
orderId
deliveryId
event
message
```

Every deployable service requires:

``` text
/health/live
/health/ready
```

Monitor:

-   HTTP latency/error rate
-   queue depth
-   failed/stalled jobs
-   PostgreSQL connectivity
-   Redis connectivity
-   service-to-service failures/latency
-   WebSocket connections
-   event failures
-   critical order/dispatch/payment flow failures

Use distributed tracing across gateway/services where practical.

## 20.20 Error Standard

Expected business failures use stable error codes.

``` text
ORDER_NOT_FOUND
ORDER_INVALID_STATE
RIDER_NOT_AVAILABLE
DELIVERY_ALREADY_ASSIGNED
PAYMENT_ALREADY_PROCESSED
MERCHANT_CLOSED
```

Transport layers translate domain/application errors to HTTP, WebSocket,
or message responses.

Do not use generic `Error` as the normal representation of expected
business conditions.

## 20.21 Testing Standard

Each service must have the appropriate combination of:

``` text
Unit tests
Integration tests
Contract tests
E2E tests
```

Critical coverage:

-   authentication
-   authorization/resource ownership
-   order creation
-   total calculation
-   order state transitions
-   cancellation
-   rider matching
-   concurrent offer acceptance
-   offer expiry
-   payment idempotency
-   duplicate webhook processing
-   event retry/idempotency
-   WebSocket authentication/authorization

Use NestJS dependency injection to replace external dependencies in unit
tests. Use real PostgreSQL/Redis-compatible test infrastructure where
correctness depends on database locking, transactions, queues, or Redis
behavior.

## 20.22 Contract Testing

Verify service contracts such as:

``` text
Gateway ↔ Identity
Gateway ↔ Order
Order ↔ Catalog
Order ↔ Merchant
Order events → Dispatch
Payment events → Order
Dispatch events → Realtime
```

A producer must not silently release a breaking API/event contract.

## 20.23 CI Quality Gate

Required before deployment:

``` text
lockfile install
lint
typecheck
unit tests
integration tests
build
dependency/security checks
```

Production deployment must stop when required checks fail.

Avoid:

-   unjustified `any`
-   giant controllers
-   giant services
-   circular dependencies
-   duplicated business rules
-   unbounded retries
-   magic strings for statuses/events
-   direct cross-service repository access

## 20.24 Naming Standard

Files:

``` text
orders.controller.ts
orders.module.ts
create-order.dto.ts
create-order.service.ts
order.repository.ts
order.entity.ts
order-status.enum.ts
order-created.event.ts
```

Classes:

``` text
OrdersController
OrdersModule
CreateOrderDto
CreateOrderService
OrderRepository
OrderCreatedEvent
```

Events:

``` text
order.created
order.confirmed
order.ready_for_pickup
dispatch.rider_assigned
payment.paid
delivery.delivered
```

Use one convention across all services.

## 20.25 Dependency Boundary Standard

Preferred dependency direction:

``` text
Domain
  ↑
Application
  ↑
Presentation / Infrastructure
```

Domain code should not directly depend on:

``` text
HTTP controllers
ORM implementation details
Redis clients
BullMQ
Socket.IO
external provider SDKs
```

Use ports/interfaces where isolation provides real value.

## 20.26 Shared Library Standard

Good shared libraries:

``` text
event envelope contracts
correlation ID utilities
logging/observability helpers
auth token contracts
common transport contracts
```

Do not share:

``` text
Order ORM entity
Payment repository
Dispatch business service
Merchant database model
```

Sharing domain persistence models between microservices creates a
distributed monolith.

## 20.27 Docker and Shutdown Standard

Every deployable service should use:

-   multi-stage Docker builds
-   production-only runtime dependencies
-   non-root runtime where practical
-   health checks
-   graceful shutdown
-   immutable release/commit image tags
-   no `.env` baked into the image

Shutdown flow:

``` text
Stop accepting new work
        ↓
Stop/finish consumers safely
        ↓
Close WebSocket resources
        ↓
Close Redis
        ↓
Close database pool
        ↓
Exit
```

## 20.28 Performance Standard

-   Measure before optimizing.
-   Add indexes based on real query patterns.
-   Avoid N+1 queries.
-   Paginate large collections.
-   Cache only when ownership/invalidation is clear.
-   Use Redis for high-frequency ephemeral state.
-   Scale stateless APIs horizontally when needed.
-   Scale workers separately from HTTP APIs.
-   Scale realtime/location independently when rider traffic grows.

## 20.29 Definition of Done for a Service

A service is production-ready only when applicable items are complete:

-   [ ] Clear business ownership
-   [ ] Dedicated database ownership
-   [ ] Correct NestJS module boundaries
-   [ ] DTO/input validation
-   [ ] Authentication and authorization
-   [ ] Database migrations
-   [ ] API/event contracts
-   [ ] Idempotency where required
-   [ ] Structured logging
-   [ ] Health endpoints
-   [ ] Stable error codes
-   [ ] Unit tests
-   [ ] Integration tests
-   [ ] Contract/E2E tests for critical paths
-   [ ] Docker build
-   [ ] CI quality gates
-   [ ] Graceful shutdown
-   [ ] Metrics/tracing/logging
-   [ ] No cross-service database access
-   [ ] Documentation updated

## 20.30 TalaDelivery NestJS Golden Rules

``` text
Controller is not the business layer.
Database is not the integration layer.
Redis is not the permanent source of truth.
WebSocket is not a second backend.
Shared library is not a shared database model.
Microservice does not mean one service per screen.
```

Build around business ownership:

``` text
Identity
Merchant
Catalog
Order
Dispatch
Payment
Notification
Realtime
```

Add a new service only when a real domain, scaling, reliability,
security, deployment, or team-ownership boundary justifies it.

------------------------------------------------------------------------

# 21. NestJS Migration Gate

Before converting any working Laravel process to NestJS:

-   [ ] Laravel behavior is known and tested.
-   [ ] Owning NestJS service is identified.
-   [ ] Database ownership is identified.
-   [ ] API/command/event contract is defined.
-   [ ] DTO/input validation is defined.
-   [ ] Authorization rules are defined.
-   [ ] Local transaction boundary is defined.
-   [ ] Idempotency requirements are defined.
-   [ ] Failure/retry behavior is defined.
-   [ ] Logs/metrics/traces are defined.
-   [ ] Unit/integration/E2E tests are prepared.
-   [ ] Flutter/Angular behavior is verified against NestJS.

Only then mark the Laravel process as successfully migrated.

# Target Outcome

Laravel proves what TalaDelivery should do.

NestJS becomes how the production TalaDelivery platform does it.

``` text
WORKING LARAVEL MVP
        ↓
Validated Business Processes
        ↓
NestJS Microservices
        ↓
Staging
        ↓
Production
        ↓
Laravel Retirement
        ↓
Future Delivery + Courier + Ride Platform
```
