---
description: Shared Project Index — publishable codebase map for Discord Preview Fixer.
read_if: Navigating the codebase, locating a link service, or deciding where new code belongs.
---

# Shared Project Index

## Architecture

- Ruby Discord bot (`discordrb`). `main.rb` wires env, logging, Sentry, the health server, and Discord event subscriptions; `lib/handlers.rb` holds the event logic so it can be unit-tested with fake events.
- Link rewriting is class-based dispatch, not a registry: each supported service subclasses `Service` (`lib/service.rb`) with `HOST_REGEX` + `REPLACEMENT_HOST`, and `LinkFixer` picks the first `Service.subclasses` match. Requiring the file in `main.rb` and `test/test_helper.rb` is the entire registration step.
- `message.rb` owns the SQLite/Sequel store mapping original Discord message IDs to posted fixed-reply IDs; this is what lets a deleted original also delete its fixed reply.
- Tests are Minitest with SimpleCov (90% branch floor), run against an in-memory DB (`DB_PATH=:memory:` in `test/test_helper.rb`).

## Project Index

- `main.rb` — Bot entrypoint: requires every service, builds `Discordrb::Bot` + `Handlers` + logger, subscribes `message` (content filtered by `LinkFixer::HTTP_REGEX`), `message_edit`, and `message_delete`, starts a daily pruner for stale message rows, starts `HealthServer`, then blocks on `BOT.run`.
- `README.md` — Ditto
- `Gemfile`, `Gemfile.lock` — Ditto
- `Rakefile` — Ditto
- `mise.toml` — Ditto
- `lefthook.yml` — Ditto
- `.rubocop.yml` — Ditto
- `Dockerfile`, `.dockerignore` — Ditto
- `compose.yml` — Ditto
- `.env.example` — Ditto
- `.editorconfig`, `.gitignore`, `.infisical.json` — Ditto
- `.mcp.json`, `.pi/mcp.json` — Ditto
- `coverage/` — Generated SimpleCov output; gitignored.
- `.github/workflows/minitest.yml` — CI gate: `bundle exec rake` then `bundle exec rubocop`.
- `.github/workflows/build-docker-image.yml`, `.github/dependabot.yml` — Ditto

### `lib/` — Bot logic and link-service definitions

- `service.rb` — `Service` base class; `fix_link` returns a rewritten URI string on a `HOST_REGEX` match, else `nil`.
- `link_fixer.rb` — Extracts URLs from message text, strips trailing punctuation, deduplicates repeated results, dispatches through `Service.subclasses`, wraps results in spoilers when the original is spoilered.
- `handlers.rb` — Discord event side effects: reply with fixed links, re-sync the reply on message edit, ignore bot authors, persist the message pair, suppress embeds, and clean up on message/fixed-reply deletion.
- `message.rb` — Sequel/SQLite connection plus the `Message` model (unique `original_message_id`, paired `fixed_message_id`, `created_at`) and `Message.prune` for stale rows.
- `message_schema.rb` — Owns the `messages` table: creates it, backfills `created_at`, and adds the `fixed_message_id` index for databases created before either existed.
- `health.rb` — `HealthServer`: loopback TCP endpoint answering `GET /healthz` with 200/503 and 404 for any other path or method, bounding request reads so a stalled client cannot block it; used by the container health check.
- `sentry.rb` — Sentry initialization (breadcrumbs logger config).
- `twitter.rb`, `pixiv.rb`, `reddit.rb`, `amiami.rb`, `instagram.rb`, `tiktok.rb` — One `Service` subclass each, differing only in `HOST_REGEX` and `REPLACEMENT_HOST` (vxtwitter.com, phixiv.net, rxddit.com, figurki.harvestasha.org, eeinstagram.com, tnktok.com).

### `test/` — Minitest suite

- `test_helper.rb` — SimpleCov setup (90% coverage minimum, branch coverage enabled), forces `DB_PATH=:memory:`, requires every `lib/` module under test.
- `link_fixer_test.rb`, `service_test.rb` — Core extraction/rewrite and dispatch behavior.
- `handlers_test.rb`, `message_test.rb`, `health_server_test.rb` — Event handlers (reply/edit/delete, bot filter, dedupe) with fake events, the Sequel model plus pruning, and the health endpoint including 404 paths and read timeouts.
- `message_schema_test.rb` — Fresh, legacy, and idempotent `MessageSchema.install` paths.
- `services_test.rb` — Table-driven per-service host matching and replacement for every supported URL shape.
