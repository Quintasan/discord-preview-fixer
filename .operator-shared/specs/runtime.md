---
description: Runtime contract for the bot process — health endpoint, storage retention, and container expectations.
read_if: Changing main.rb wiring, HealthServer, the messages table, or Docker/compose deployment.
---

# Runtime

## Health endpoint

`HealthServer` serves `GET /healthz` on loopback (`HEALTHCHECK_PORT`, default 8080):

- `200 ok` when the bot is connected to Discord,
- `503 unhealthy` when it is not,
- `404 not found` for any other path or method.

The Docker `HEALTHCHECK` polls `/healthz` and greps the body for `ok`. The server binds loopback
only; it is for the container runtime, not public traffic.

## Storage retention

`messages` maps original Discord message IDs to their fixed-reply IDs. A row is removed as soon as
the deletion of either message is observed. Deletions that happen while the bot is offline are never
observed, so `main.rb` prunes rows older than 30 days once per day. `created_at` is set on insert and
is backfilled for databases created before the column existed.
