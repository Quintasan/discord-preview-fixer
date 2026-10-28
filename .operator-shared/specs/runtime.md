---
description: Runtime contract for the bot process — health endpoint, retention/prune, watchdog, shutdown, and container expectations.
read_if: Changing main.rb wiring, HealthServer, the messages table/prune, or Docker/compose deployment.
---

# Runtime

## Health Endpoint

`HealthServer` serves `GET /healthz` on loopback (`HEALTHCHECK_PORT`, default 8080):

- `200 ok` when the bot is connected to Discord,
- `503 unhealthy` when it is not,
- `404 not found` for any other path or method.

The Docker `HEALTHCHECK` polls `/healthz` and greps the body for `ok`. The server binds loopback
only; it is for the container runtime, not public traffic.

## Storage Retention

`messages` maps original Discord message IDs to their fixed-reply IDs and the channel that holds the
reply. A row is removed as soon as the deletion of either message is observed. Deletions that happen
while the bot is offline are never observed, so the pruner forgets rows older than `RETENTION_DAYS`
(default 30) on an hourly loop that starts with the process.

Retention is forgetting, not cleanup: pruning never deletes a fixed reply. It therefore makes no
Discord call, needs no gateway connection or channel lookup, and cannot fail halfway through a run.
The costs of that simplicity are accepted deliberately: replies to messages deleted while the bot was
offline stay in their channels, and an edit to a message past the window is ignored instead of being
allowed to post a second reply. Retained records still behave exactly as before, including deleting
the reply when the original is deleted.

`created_at` is set explicitly on insert because databases created before the column existed have no
default. The schema owns the `channel_id` migration; `channel_id` is still written on insert but is
no longer read by anything.

## Storage Scaling

One `messages` table stays, deliberately. Measured on a 2M-row database: an indexed point lookup
(`original_message_id`, the hot path on every message/edit/delete) costs the same at 1k rows and at
2M rows — table size is not a per-guild cost, because the lookup never scans. The only size-sensitive work is the prune scan. Pruning runs hourly and deletes in one bulk statement,
so its cost tracks the stale row count, not the table: measured at 200k rows, an unindexed pass costs
~11 ms of full scan no matter how few rows are stale, while the `created_at` index turns the pass into
a range scan whose cost follows the stale set — 0.1 ms at 20 stale rows, 0.2 ms at 280 (an hourly pass
over a 30-day window), 1.2 ms at 2 000 (the same window pruned daily). Cadence and the index compound:
hourly keeps staleness at `PRUNE_INTERVAL / RETENTION_SECONDS` of the window, and the index makes the
pass proportional to that fraction instead of to the table.

So per-guild tables are rejected as a scaling device: they buy nothing on the hot path, cost a guild
lookup the bot otherwise never needs (DMs have no guild), turn `Message`'s single dataset into
mutable process-wide state shared with the prune thread, and multiply `MessageSchema.install`'s
per-table migrations and their failure modes by the guild count. The sanctioned levers are the hourly
cadence and the `created_at` index; steady-state size stays near one retention window.

Batching the prune has been considered and rejected twice over. Sequel offers no `find_each`/`in_batches`,
and `Dataset#delete` on a limited dataset raises `Sequel::InvalidOperation` on SQLite (its native
`DELETE ... LIMIT` needs a compile-time flag the bundled sqlite lacks), so the only batching shape is
select keys → delete by key — several extra scans to shave a few milliseconds off a 0.2 ms statement.
The bulk delete stays one statement. The bundled `pagination` extension is not an alternative: it is
opt-in, counts the whole dataset per call, and pages by offset, so a page that deletes rows makes the
next page skip them.

A separate prune process was also considered and rejected. It would work — same image, a second
compose service, a shared volume, WAL across processes — but it forces two things it should not have
to: every container that loads `message.rb` migrates the schema at require time, and two migrators
racing on a legacy database raise `duplicate column name` (reproduced), so the schema install would
have to be extracted from `message.rb` into an explicit boot step first. The image's baked-in
`HEALTHCHECK` would also need disabling per service, and the release workflow asserts exactly two
`IMAGE_TAG` references in `compose.yml`, so the split reaches into release tooling. Against that, the
isolated work is one 0.2 ms statement per hour that needs no gateway, which the existing thread
already isolates with a rescue.

The `created_at` index costs ~60% file size (117 → 187 MB at 2M rows) and a 555 ms one-time build on
a large legacy database; insert throughput is unaffected. It pays only while the stale set is small —
at 5% stale and above the planner ignores it (898 → 882 ms, 100% stale is 18.5 s either way) — which
is exactly the case the hourly cadence guarantees.

## Process Lifecycle

`main.rb` loads `dotenv` before initializing Sentry and the database, so `.env` supplies `SENTRY_DSN`
and `DB_PATH`. The prune thread starts with the process — forgetting never resolves channels — and
then sleeps a day between runs.

A watchdog stops the bot when it has been disconnected for `WATCHDOG_GRACE_SECONDS` (default 300), so
the container restart policy can replace a process that is alive but not working. `SIGINT`/`SIGTERM`
set a shutdown flag; a normal thread stops the bot, and the `ensure` block stops the health server and
disconnects the database.
