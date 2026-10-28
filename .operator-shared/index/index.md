---
description: Shared Project Index — publishable codebase map for Discord Preview Fixer.
read_if: Navigating the codebase, locating a link service, or deciding where new code belongs.
---

# Shared Project Index

## Architecture

- Ruby Discord bot (`discordrb`). `main.rb` loads dotenv first, then wires env, logging, Sentry, the health server, the prune loop, the disconnect watchdog, and Discord event subscriptions; `lib/handlers.rb` holds the event logic so it can be unit-tested with fake events.
- Link rewriting is class-based dispatch, not a registry: each supported service subclasses `Service` (`lib/service.rb`) with `HOST_REGEX` + `REPLACEMENT_HOST`, and `lib/services.rb` is the manifest that loads them. `LinkFixer` picks the first `Service.subclasses` match.
- `HandlerSupport` serializes handler bodies, filters bots, suppresses embeds, and reports unexpected failures to Sentry (discordrb otherwise swallows handler exceptions into its own logger). `ReplyContent` fits links into Discord's 2000-character limit.
- `message.rb` owns the SQLite/Sequel store mapping original Discord message IDs to posted fixed-reply IDs and their channel; `pruner.rb` only forgets stale records — retention never deletes replies, and edits past the window are ignored rather than re-fixed.
- Tests are Minitest with SimpleCov (90% branch floor), run against an in-memory DB (`DB_PATH=:memory:` in `test/test_helper.rb`).

## Project Index

- `main.rb` — Entrypoint: loads dotenv, requires the services manifest and app modules, builds `Discordrb::Bot` + `Handlers` + logger, subscribes `message` (content filtered by `LinkFixer::HTTP_REGEX`), `message_edit`, and `message_delete`, starts the prune loop (immediately, no gateway needed) and disconnect watchdog, starts `HealthServer`, installs SIGINT/SIGTERM shutdown, and blocks on `BOT.run` with health/DB cleanup in `ensure`.
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
- `.github/workflows/minitest.yml` — CI gate: tests then RuboCop, plus a no-push Docker build.
- `.github/workflows/build-docker-image.yml` — Tag-triggered GHCR build; asserts the tag matches `compose.yml` before building.
- `.github/dependabot.yml` — Weekly Bundler, GitHub Actions, and Docker updates.

### `lib/` — Bot logic and link-service definitions

- `service.rb` — `Service` base class; `fix_link` returns a rewritten URI string on a `HOST_REGEX` match, else `nil`; `rewrite` is the overridable host/path/query hook.
- `services.rb` — Registration manifest; requires every `Service` subclass. Required by `main.rb` and the test helper.
- `link_fixer.rb` — Extracts URLs, strips trailing punctuation, skips inline/fenced code, tracks per-link spoilers (including multiline), deduplicates fixed links, and dispatches through `Service.subclasses`.
- `handler_support.rb` — Shared handler behavior: mutex-guarded execution, bot filtering, embed suppression, and Sentry reporting for unexpected errors.
- `reply_content.rb` — Fits fixed links into one message: keeps complete links up to 2000 characters, drops the rest, and truncates a single oversized link.
- `handlers.rb` — Discord event dispatch: reply with fixed links, re-suppress embeds and re-sync the reply on edit, ignore bot authors, ignore duplicate records, persist the message pair with its channel, suppress embeds, recover when the fixed reply is gone, and clean up on message/fixed-reply deletion.
- `message.rb` — Sequel/SQLite connection plus the `Message` model (`original_message_id`, `fixed_message_id`, `channel_id`, `created_at`); `Message.record` upserts with an explicit timestamp and `Message.prune` is one bulk delete past the cutoff.
- `message_schema.rb` — Owns the `messages` table: creates it, backfills `created_at`, adds `channel_id`, and adds the `fixed_message_id` and `created_at` indexes for legacy databases.
- `pruner.rb` — Retention policy: forgets records past the window; never touches Discord, so it needs no bot or gateway.
- `health.rb` — `HealthServer`: loopback TCP endpoint answering `GET /healthz` with 200/503 and 404 for any other path or method, bounding request reads so a stalled client cannot block it; used by the container health check.
- `sentry.rb` — Sentry initialization (breadcrumbs logger config).
- `twitter.rb`, `pixiv.rb`, `reddit.rb`, `amiami.rb`, `instagram.rb`, `tiktok.rb` — One `Service` subclass each, differing only in `HOST_REGEX` and `REPLACEMENT_HOST` (vxtwitter.com, phixiv.net, rxddit.com, figurki.harvestasha.org, eeinstagram.com, tnktok.com). Twitter also covers `x.com`/`mobile.`; Reddit covers `www.`/`old.`/`new.`/`np.`/`i.`; Instagram covers `m.`/`instagr.am`.

### `test/` — Minitest suite

- `test_helper.rb` — SimpleCov setup (90% coverage minimum, branch coverage enabled), forces `DB_PATH=:memory:`, requires the services manifest and every `lib/` module under test.
- `link_fixer_test.rb`, `service_test.rb`, `services_test.rb` — Extraction/rewrite and dispatch, per-link spoilers and code spans, table-driven host variants, disjoint service matching.
- `handlers_test.rb`, `message_test.rb`, `health_server_test.rb` — Reply/edit/delete behavior (re-suppression, no-ping mentions, truncation, UnknownMessage recovery, concurrency, bot filter, dedupe) with fake events, the Sequel model plus pruning, and the health endpoint including 404 paths and read timeouts.
- `message_schema_test.rb`, `pruner_test.rb` — Fresh, legacy, and idempotent `MessageSchema.install` paths; forgetting past the window, keeping retained rows, and idempotent drains.
