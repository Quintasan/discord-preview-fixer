# Copilot / AI Agent Instructions

This repository implements a small Discord bot that replaces links to services (Twitter/X, Pixiv, TikTok, Reddit, AmiAmi) with alternate preview-friendly domains. Use these notes to make focused, correct changes quickly.

**Big Picture**
- **Bot entry:** `main.rb`: creates `BOT` (Discordrb::Bot) and registers message handlers.
- **Service modules:** `lib/*.rb` — each module exports a `REGEX` constant and a `fix_link(event)` method that returns the replacement URL string.
- **Tests:** `test/*_test.rb` use `Minitest` and a simple `Event` Struct that carries a `message` string to call `Module.fix_link(event)`.

**How handlers work (important patterns)**
- **Detection:** `BOT.message(contains: SomeModule::REGEX) do |event| ... end` — handlers call the corresponding `fix_link` and then `event.respond(...)`.
- **Suppress embeds:** handlers call `event.message.suppress_embeds` after posting the replacement link.
- **Cleanup on delete:** each handler registers `BOT.add_await!(Discordrb::Events::MessageDeleteEvent, timeout: 30)` and deletes the bot response if the original message is deleted.

**Service module conventions (follow these exactly)**
- **File location:** `lib/<service>.rb` (examples: `lib/twitter.rb`, `lib/pixiv.rb`).
- **Constants & API:** define `REGEX` (a Ruby `Regexp`) and `def self.fix_link(event)` which:
  - reads the incoming message with `message = event.message.to_s` or `event.message.to_s.match(REGEX).to_s`
  - returns a transformed URL string (commonly using `String#gsub`).
- **Regex style:** many modules use named captures (e.g. `%r{...(?<domain>twitter.com)...}i`) — keep those if you need to branch on capture groups.

**Examples (copyable patterns)**
- `lib/twitter.rb` — detect `twitter.com` or `x.com`, then `old_link.gsub('twitter.com', 'vxtwitter.com')`.
- `lib/pixiv.rb` — supports optional locale path segments (`/en/`) and `www` variations; tests cover `https://www.pixiv.net/en/artworks/ID` and `https://pixiv.net/artworks/ID`.

**Testing & local workflows**
- **Ruby version:** `Gemfile` states `ruby '3.4.1'` (use that when running or CI).
- **Install deps:** `bundle install --jobs=$(nproc)`
- **Run tests:** `bundle exec rake` (or `bundle exec rake test`) — `Rakefile` defines the default test task.
- **Run the bot locally:** create `.env` with `DISCORD_PREVIEW_FIXER_TOKEN=<token>` then `ruby main.rb` (or use `docker compose up` per `README.md`).

**Logging & instrumentation**
- The app uses `TTY::Logger` as `LOGGER` (global constant). Log messages are present in `main.rb` around each handler: include `service`, `user`, and `fixed_link` metadata.

**Integration notes / gotchas discovered in code**
- `main.rb` contains a likely bug in the Reddit handler: it calls `TikTok.fix_link(event)` and later references `new_link` and `response = event.respond(new_link, ...)`. Tests expect `Reddit.fix_link` to return an `rxddit`-prefixed link; be cautious when editing `main.rb`.
- Tests assume modules are loadable in the test environment (`test/test_helper.rb` uses `require 'amiami'` etc.). When running tests via Bundler, the `lib/` path is available — prefer `bundle exec rake` to match CI.

**How to add a new service**
- Add `lib/<service>.rb` with `REGEX` and `self.fix_link(event)`.
- Add `BOT.message(contains: <Service>::REGEX) do |event| ... end` in `main.rb` following existing handler structure (respond, suppress_embeds, add_await! cleanup).
- Add a `test/<service>_test.rb` that follows existing tests: create an `Event` with `message: '...'` and assert the expected replacement string.

If anything is unclear or you want examples for a new service implementation, tell me which service and I will add a small scaffolded `lib/` module and tests. Would you like me to include a short example for adding a new service?
