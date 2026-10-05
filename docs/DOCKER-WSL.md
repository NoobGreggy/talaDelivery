# Docker in WSL Ubuntu

Run the API, Socket.IO and seven supporting services from Ubuntu:

```sh
cd /home/gregg/system/taladelivery-backend
docker compose --env-file .env.docker up -d --build
docker compose --env-file .env.docker ps
docker compose --env-file .env.docker logs --tail=100 api-gateway realtime-service
```

Gateway: `http://localhost:3000`; Socket.IO: `http://localhost:3008`.
Only these two ports are published. Internal services use Docker DNS names.
Mobile LAN access may require WSL/Windows forwarding and firewall configuration
or an HTTPS tunnel.

## Existing connections — no new storage

The services load existing credentials, JWT secrets, API keys, Redis password and
queue prefix from the private `.env`. The private `.env.docker` contains Docker
routing overrides only. Both files are ignored by Git.

The old PostgreSQL connection remains port 5433 and the old Redis connection
remains port 6380. Inside Docker, `host.docker.internal` resolves to the host via
`host-gateway`; `127.0.0.1` would incorrectly refer to each application container.
Existing service database names and Redis database are unchanged.

There are no PostgreSQL/Redis services or storage volumes defined in this Compose
configuration. The existing `postgres_db` and `redis-server-new` containers are
not managed or stopped by this stack. The temporary isolated storage containers
from the initial setup attempt were stopped; their volumes were retained.

Runtime uses production mode with schema synchronization disabled. Migrations
are NOT run at startup. The migration service is restricted to the optional
`maintenance` profile; do not run it against existing databases without checking
migration history and taking backups first.

Stop only the application stack:

```sh
docker compose --env-file .env.docker stop
```
