---
description: Contract for detecting and rewriting links in Discord messages, including the fixed-reply lifecycle.
read_if: Changing link detection, adding a Service subclass, or touching message reply/edit/delete handling.
---

# Link Fixing

## Supported Services

Each supported service is a `Service` subclass with `HOST_REGEX` (matched against `URI#host`) and
`REPLACEMENT_HOST`. `LinkFixer` extracts every `http`/`https` URL from a message, strips trailing
punctuation, and rewrites the host of the first matching service. A URL matched by no service
produces no output.

Registering a service is exactly two steps:

1. Add `lib/<service>.rb` subclassing `Service`.
2. `require` it from both `main.rb` and `test/test_helper.rb`.

Dispatch walks `Service.subclasses`, so a new service must not match a host another service owns.

## Reply Lifecycle

- At most one fixed reply exists per original message. It is enforced by the unique index on
  `Message#original_message_id`, and `Handlers` skips any message that already has a record.
- The bot suppresses the original message's embeds and replies with each distinct fixed link, one per line.
- When the original is spoilered (`||…||`), every fixed link is wrapped in spoilers.
- Editing the original re-syncs the reply: a changed link edits the reply in place, removing the
  link deletes the reply and its record, and adding one posts a reply.
- Deleting the original deletes the fixed reply and its record; deleting the fixed reply drops the
  orphaned record.
- Messages authored by bots, including this one, are ignored so bot-to-bot traffic cannot loop.

## Invariants

- `fixed_message_id` always refers to the bot's reply and survives edits, so the record never needs
  re-pointing.
- Reply, edit, and delete failures are logged (and reported to Sentry) but never raise out of a
  handler. A failed Discord delete still destroys the local record.
