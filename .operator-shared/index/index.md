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

- `main.rb` — Bot entrypoint: requires every service, builds `Discordrb::Bot` + `Handlers` + logger, starts `HealthServer`, subscribes `message` (content filtered by `LinkFixer::HTTP_REGEX`) and `message_delete`, then blocks on `BOT.run`.
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
- `link_fixer.rb` — Extracts URLs from message text, strips trailing punctuation, dispatches through `Service.subclasses`, wraps results in spoilers when the original is spoilered.
- `handlers.rb` — Discord event side effects: reply with fixed links, persist the message pair, suppress embeds, and clean up on message deletion.
- `message.rb` — Sequel/SQLite setup plus the `Message` model (unique `original_message_id`, paired `fixed_message_id`).
- `health.rb` — `HealthServer`: loopback TCP health endpoint returning 200 when the bot reports connected, else 503; used by the container health check.
- `sentry.rb` — Sentry initialization (breadcrumbs logger config).
- `twitter.rb`, `pixiv.rb`, `reddit.rb`, `amiami.rb`, `instagram.rb`, `tiktok.rb` — One `Service` subclass each, differing only in `HOST_REGEX` and `REPLACEMENT_HOST` (vxtwitter.com, phixiv.net, rxddit.com, figurki.harvestasha.org, eeinstagram.com, tnktok.com).

### `test/` — Minitest suite

- `test_helper.rb` — SimpleCov setup (90% branch minimum), forces `DB_PATH=:memory:`, requires every `lib/` service under test.
- `link_fixer_test.rb`, `service_test.rb` — Core extraction/rewrite and dispatch behavior.
- `handlers_test.rb`, `message_test.rb`, `health_server_test.rb` — Event handlers with fake events, the Sequel model, and the health endpoint.
- `twitter_test.rb`, `pixiv_test.rb`, `reddit_test.rb`, `amiami_test.rb`, `instagram_test.rb`, `tiktok_test.rb` — Per-service host matching and replacement tests.
