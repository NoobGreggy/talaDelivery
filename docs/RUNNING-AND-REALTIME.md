# Running TalaDelivery Backend + Realtime (WebSocket) Integration

Companion to [`nestjs_api.md`](../nestjs_api.md) (full API reference) and
[`internal-contracts.md`](./internal-contracts.md) (service-to-service contract).

Everything below was verified against a running local stack on 2026-10-04.

---

## 1. Prerequisites

| Requirement | Version | Notes |
|---|---|---|
| Node.js | `>=22 <25` | `package.json` `engines` |
| PostgreSQL | 14+ | One database per service |
| Redis | 5+ | BullMQ broker — **required**, see §1.2 |
| Docker | optional | Only for `docker compose up` (§3) |

### 1.1 Install

```bash
cd taladelivery-backend
npm install
```

### 1.2 Why Redis is not optional

Services enqueue domain events to BullMQ. Redis being unreachable is handled
fail-soft (the request completes and the job is dropped with a warning), so HTTP
endpoints stay up — but **no realtime events will ever be emitted**, because
`realtime-service` consumes those queues. A WebSocket that connects but never
receives anything is almost always this.

---

## 2. Environment

Copy the template and edit:

```bash
cp .env.example .env
```

`.env` is a single file shared by all services. Two rules matter:

**1. Ports are host-specific in this repo.** `.env.example` defaults to the
docker-compose ports (`5432`/`6379`); a local native install often differs. This
repo's `.env` uses `5433`/`6380`. Match yours to what is actually listening.

**2. Never set a global `POSTGRES_DB_NAME`.** Each service owns exactly one
database and falls back to its own `*_DB_NAME` constant. A global override
points all nine services at a single database, and because dev runs with
TypeORM `synchronize: true`, they will cheerfully create each other's foreign
tables. `scripts/start-dev.ps1` sets the variable **per process**; do the same.

Key variables:

| Variable | Purpose |
|---|---|
| `APP_API_KEY` | Value clients must send as `X-App-Key` on every request |
| `INTERNAL_API_TOKEN` | `X-Service-Token` for `/internal/*` calls |
| `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` | Must match across services and the gateway |
| `POSTGRES_*`, `REDIS_*` | Datastores |
| `*_SERVICE_URL` | Used by the gateway to proxy to each service |

---

## 3. Databases

Nine services, eight databases (the gateway has none):

```
taladelivery_identity     taladelivery_order
taladelivery_merchant     taladelivery_dispatch
taladelivery_catalog      taladelivery_payment
                          taladelivery_notification
                          taladelivery_realtime
```

**Docker** — `docker/init.sql` creates them on first boot:

```bash
docker compose up -d postgres redis
```

**Native Postgres** — create them yourself, then create the role and grant:

```sql
CREATE ROLE tala WITH LOGIN PASSWORD 'tala_dev_password';
CREATE DATABASE taladelivery_identity OWNER tala;
-- ...repeat for each database above
```

In development, schema is created automatically: every service runs TypeORM with
`synchronize: true` when `NODE_ENV !== 'production'`. Structured migrations exist
and are required for production, but you do not need to run them for local dev:

```bash
npm run migration:run        # all services, production-style
```

---

## 4. Run the services

### Option A — all at once (recommended)

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File scripts\start-dev.ps1

# PowerShell also works on macOS/Linux
pwsh -File scripts/start-dev.ps1

# Skip realtime (port 3008) if you do not need push events
pwsh -File scripts/start-dev.ps1 -NoRealtime
```

Each service runs as its own `ts-node` process with its own `POSTGRES_DB_NAME`.
Logs land in `.logs/<service>.log` (stdout) and `.logs/<service>.err.log`
(stderr). The script finishes with a health probe per service.

> The script staggers starts by 4s on purpose. Each `ts-node` process costs
> 150–250MB; launching all nine at once exhausts memory and kills the last one
> with `Zone Allocation failed - process out of memory`.

Stop everything:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\stop-dev.ps1
```

### Option B — one service, with watch

```bash
npm run start:dev:identity      # or :api-gateway, :merchant, :catalog,
                                 # :order, :dispatch, :payment, :notification, :realtime
```

> Prefer `npm run typecheck` over `npm run build` as a pre-flight check —
> `build` has been observed to pass while `ts-node` fails at boot on the same
> file.

### Option C — Docker Compose

```bash
docker compose up --build
```

Brings up Postgres, Redis, runs migrations, then all nine services.

---

## 5. Ports and the entry point

| Port | Service | Purpose |
|---:|---|---|
| **3000** | **api-gateway** | **The only public HTTP entry point.** Proxies `/api/v1/*` by path prefix |
| 3001 | identity | auth, users, admin customers/users |
| 3002 | merchant | stores |
| 3003 | catalog | products, categories |
| 3004 | order | orders |
| 3005 | dispatch | riders, deliveries, zones, dashboard |
| 3006 | payment | payments |
| 3007 | notification | notifications |
| 3008 | realtime | **Socket.IO** — connect here directly |

Call the gateway, never the individual services:

```
POST http://localhost:3000/api/v1/auth/login
```

Health checks:

```bash
curl http://localhost:3000/health/live    # { "data": { "status": "ok", ... } }
curl http://localhost:3000/health/ready   # dependency check
```

Swagger UI is served per service at `/docs` (the gateway owns its own; each
service exposes its own too).

---

## 6. Seed an admin

`seed-admin` is a standalone script — there is **no npm script** for it, so run it
directly. It is idempotent (it exits early if the email already exists):

```bash
node -r ts-node/register -r tsconfig-paths/register \
  apps/identity-service/src/scripts/seed-admin.ts
```

Defaults: `admin@taladelivery.com` / `Admin@123456`. Override with
`SEED_ADMIN_EMAIL`, `SEED_ADMIN_PASSWORD`, `SEED_ADMIN_NAME`.

Once logged in, an admin can provision more platform admins from the UI
(`/admin-users`) or the API:

```
POST /api/v1/admin/users
{ "name": "...", "email": "...", "password": "...", "status": "ACTIVE" }
```

This endpoint can only create `platform_admin` — there is no `role` field. Store
admins need a `store_users` membership row that only merchant-service owns.

---

# 7. Realtime / WebSocket

## 7.1 Connect to port 3008, not the gateway

**The gateway does not proxy WebSockets.** There is no `/socket.io` entry in its
routing table, so:

```
GET http://localhost:3000/socket.io/?EIO=4&transport=polling   ->  404
GET http://localhost:3008/socket.io/?EIO=4&transport=polling   ->  200 (Engine.IO handshake)
```

Point your client directly at `http://localhost:3008`, or add a `/socket.io`
proxy in your own dev server. The Angular apps do the latter — see
`talaDelivery-admin/proxy.conf.json`:

```json
{
  "/api":       { "target": "http://localhost:3000", "secure": false, "changeOrigin": true },
  "/socket.io": { "target": "http://localhost:3008", "secure": false, "ws": true, "changeOrigin": true }
}
```

## 7.2 Connection contract

| | |
|---|---|
| Namespace | `/realtime` |
| Path | `/socket.io` |
| Transports | `websocket` and/or `polling` |
| Auth | `handshake.auth.token` = **access** JWT from `POST /api/v1/auth/login` |
| CORS | `origin: true, credentials: true` (any origin) |

```ts
import { io } from 'socket.io-client';

const socket = io('http://localhost:3008/realtime', {
  path: '/socket.io',
  transports: ['websocket', 'polling'],
  auth: { token: accessToken, },   // NOT query param, NOT the refresh token
  reconnectionAttempts: 10,
  reconnectionDelay: 2000,
});
```

The gateway calls `verifyAccess`, so a **refresh token will be rejected** — it
shares the signing shape but not the type claim.

## 7.3 Subscribe to rooms

Rooms are authorized **at subscribe time**. Membership is not implicit: you must
emit `subscribe` for each room you want, and re-emit after every reconnect
(the server keeps no memory across reconnects).

```ts
socket.emit('subscribe',   { room: 'user:42' });   // ack via callback
socket.emit('unsubscribe', { room: 'user:42' });
```

### ⚠️ Ack shape is wrapped

The gateway wraps handler returns in the standard `{ success, message, data }`
envelope, so a Socket.IO ack callback receives that object — **not** a bare
`{ success }`. The outer `success` is `true` even when the subscription was
refused:

```jsonc
// subscribing to a room you do not own
{ "success": true, "message": "OK", "data": { "success": false, "error": "Forbidden." } }
```

**Check `ack.data.success`, and read failures from `ack.data.error`.** Testing
`ack.success` silently reports every forbidden subscription as a success.

```ts
const ack = await socket.emitWithAck('subscribe', { room });
if (!ack.data.success) console.warn(ack.data.error);
```

### Room authorization rules

| Room | Allowed |
|---|---|
| `user:<id>` | only that user (`id` must equal your own) |
| `order:<id>` | **any** authenticated user |
| `admin:…` (e.g. `admin:platform`) | `platform_admin` |
| `merchant:<id>` | `store_admin`, `platform_admin` |
| `rider:<id>` | `rider`, `platform_admin` |
| `customer:<id>` | `customer`, `platform_admin` |

Anything else is refused.

> `order:<id>` is authorized to every authenticated user. Room membership is a
> routing filter, **not** an authorization boundary for order data. Enforce
> "is this order actually mine" in your API call before rendering its contents.

## 7.4 Server → client events

### `order.updated`

Emitted by order-service on status changes.

```jsonc
{
  "orderId": 42, "orderNumber": "ORD-00042",
  "storeId": 3, "customerId": 7, "deliveryId": 15,
  "status": "CONFIRMED", "paymentStatus": "PENDING",
  "total": "249.00", "eventType": "order.confirmed",
  "updatedAt": "2026-10-04T13:29:28.865Z"
}
```

Rooms: `order:<orderId>`, `user:<customerId>`, `customer:<customerId>`,
`merchant:<storeId>`.

> `status`/`paymentStatus` are the enum strings; `total` is a **string**
> (Laravel decimal cast), not a number — parse it before doing arithmetic.

### `rider.location`

Emitted when a rider's position is recorded, and also produced by a rider client
emitting `location:update`.

```jsonc
{
  "deliveryId": 15, "riderId": 9,
  "latitude": 14.5995, "longitude": 120.9842,
  "accuracyM": 8, "headingDeg": 92, "speedMps": 6.4,
  "timestamp": "2026-10-04T13:29:28.865Z"
}
```

Rooms: `order:<deliveryId>` and `rider:<riderId>`.

> Two shapes exist for this event. The Redis path (dispatch-service publisher)
> includes `riderId`, `accuracyM`, `headingDeg`, `speedMps`. The client-emitted
> path (`location:update`) sends only `{ deliveryId, latitude, longitude }` and is
> emitted by the gateway itself, so those extra fields are absent. Type them as
> nullable.

### `rider.application`

A new rider applied. Sent only to `admin:platform`.

```jsonc
{ "userId": 76, "riderId": 25, "name": "...", "email": "...", "vehicleType": "MOTORCYCLE", "appliedAt": "..." }
```

## 7.5 Client → server events

| Event | Payload | Who |
|---|---|---|
| `subscribe` | `{ room: string }` | any authenticated |
| `unsubscribe` | `{ room: string }` | any authenticated |
| `location:update` | `{ deliveryId, latitude, longitude }` | **riders only** |

```ts
socket.emit('location:update', { deliveryId: 15, latitude: 14.5995, longitude: 120.9842 });
```

Rider location does **not** require a separate HTTP call — emitting this is
enough to push a position to the customer and dispatch.

## 7.6 Lifecycle

```ts
socket.on('connect', () => {
  // Re-subscribe EVERY time: rooms do not survive a reconnect.
  socket.emit('subscribe', { room: `user:${userId}` });
});

socket.on('disconnect', () => {/* offline UI */});
socket.on('connect_error', () => {/* bad/expired token */});
```

- **After login** → `connect()`
- **After a token refresh** → tear down and reconnect; the token is verified at
  connect time, so a socket opened with a stale token will fail to reconnect.
- **On logout** → `disconnect()` and clear listeners, so no session can be reused.
- Server pings every 25s; 20s without a pong drops the socket.

## 7.7 Checking live state

```bash
curl http://localhost:3000/api/v1/internal/admin/totals -H "X-Service-Token: $INTERNAL_API_TOKEN"
```

Returns `{ connectedSockets, rooms }` — the authoritative list of who is
connected and which rooms exist. Useful for confirming a subscribe landed.

## 7.8 Angular reference

`talaDelivery-admin/src/app/core/realtime/realtime.service.ts` is a complete,
working implementation (Angular 21 signals + rxjs): connection status as a
signal, rooms re-subscribed on `connect`, and typed event subjects.

For Flutter apps, use the **`socket_io_client`** package — see §7.9.

## 7.9 ⚠️ Flutter apps: `/broadcasting/auth` no longer exists

The Flutter apps (`talaDelivery-customer`, `talaDelivery-rider`) still contain
Laravel/Reverb code — e.g. `rider_realtime_service.dart` opens a raw
`WebSocketChannel` and signs channel requests against `POST /broadcasting/auth`
with form-encoded `channel_name` / `socket_id`.

**This backend removed that path.** `/broadcasting` returns 404, and a raw
WebSocket will never speak Socket.IO's Engine.IO handshake. Those Flutter
realtime services are stale and need rewriting against the contract in §7.2.

There is no way to adapt a Reverb client to this server; the protocol differs at
the handshake. Rewrite is the only fix.

---

## 8. Troubleshooting

| Symptom | Likely cause |
|---|---|
| Socket connects, no events ever arrive | Redis down, or `realtime-service` not running. Check `/internal/admin/totals` and `.logs/realtime-service.err.log` |
| Immediate disconnect after connect | Missing/invalid `token`, or a refresh token was used instead of an access token |
| 404 on `/socket.io` | Connected via the gateway. Go to port 3008 or proxy it |
| `subscribe` seems to succeed but no events | You checked `ack.success` instead of `ack.data.success` |
| Events stop after a reconnect | Rooms were not re-subscribed |
| Request hangs instead of erroring | Redis unreachable and fail-soft disabled (`EVENTS_FAIL_SOFT=false`) |
| Dashboard shows `orders: 0` | Cross-service totals degraded to zero; check each service's `.logs` |
| Service killed with `Zone Allocation failed` | Started all services without the 4s stagger — use `scripts/start-dev.ps1` |
| `npm run build` passes but the service will not boot | Use `npm run typecheck` instead; it uses the runtime tsconfig |

---

## 9. Quick reference

```bash
# Start / stop
pwsh -File scripts/start-dev.ps1
pwsh -File scripts/stop-dev.ps1

# Login
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "X-App-Key: change-me-dev-api-key" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@taladelivery.com","password":"Admin@123456"}'

# Health
curl http://localhost:3000/health/live

# Checks
npm run typecheck
npm test
```

WebSocket: `http://localhost:3008/realtime`, path `/socket.io`,
`auth: { token: <access JWT> }`, subscribe `{ room }`, check `ack.data.success`.