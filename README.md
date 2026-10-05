# TalaDelivery NestJS API

NestJS microservices backend for the admin, merchant, customer and rider apps.
This branch replaces the legacy Laravel API; it does not include Laravel services.

## Repository branches

All projects use `https://github.com/NoobGreggy/talaDelivery` with separate branches:

| Project | Branch |
| --- | --- |
| NestJS backend | `features/nestjs-api` |
| Admin | `features/admin` |
| Merchant | `features/merchant` |
| Customer Flutter app | `customer` |
| Rider Flutter app | `rider` |

Clone each branch into its own sibling directory when running the full workspace.

## Setup

1. Install Node.js 22-24, PostgreSQL, and Redis, or use Docker Compose.
2. Run `npm ci`, copy `.env.example` to `.env`, and configure local connections
   and new secrets. Never use development placeholder secrets in production.
3. For native development, create the service databases with
   `node test/ensure-databases.mjs`, run `npm run migration:run`, then use
   `scripts/start-dev.ps1`. For containers, see `docker-compose.yml` and
   [running the backend](docs/RUNNING-AND-REALTIME.md). For the Ubuntu
   Docker installation, see [Docker in WSL](docs/DOCKER-WSL.md).
4. Connect the clients to the gateway (port 3000) and Socket.IO realtime service
   (port 3008). Configure private Flutter `config/local.json` files separately;
   these files, `.env`, runtime logs and compiled APKs are not committed.
5. Run `npm run typecheck` and `npm test -- --runInBand` before deploying.

## Updates included

- Rider approval, Tala coin balances and per-delivery-zone deductions, including
  negative balances and admin alerts.
- Dynamic admin store categories and Flutter icon identifiers; merchant-owned
  product categories and product image support.
- Admin order monitoring, merchant order notifications, and Socket.IO feeds.
- Admin-assigned store delivery zones and API-calculated checkout delivery fees.
- Rider/customer NestJS integration, protected delivery tracking snapshots and
  location broadcasts, active rider background GPS, road routes, and external
  Google Maps/Apple Maps navigation.

See [API reference](nestjs_api.md), [internal contracts](docs/internal-contracts.md),
and [workspace changes and test notes](docs/WORKSPACE-RUNNING.md).

Physical-device background GPS and iOS navigation still require phone testing.
Background tracking is not guaranteed after force-stopping the app. Use
HTTPS/WSS and replace all development credentials before production deployment.
