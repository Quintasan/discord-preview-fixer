---
description: Contract for detecting and rewriting links in Discord messages, including the fixed-reply lifecycle, spoiler/code handling, and message limits.
read_if: Changing link detection, adding a Service subclass, spoiler/code handling, or touching message reply/edit/delete handling.
---

# Link Fixing

## Supported Services

Each supported service is a `Service` subclass with `HOST_REGEX` (matched against `URI#host`) and
`REPLACEMENT_HOST`. Subclasses may override `rewrite` to adjust the path or query; the default
rewrites only the host. `LinkFixer` extracts every `http`/`https` URL from a message, strips trailing
punctuation, and rewrites the host of the first matching service. A URL matched by no service
produces no output.

Registering a service is exactly two steps:

1. Add `lib/<service>.rb` subclassing `Service`.
2. Add it to `lib/services.rb`, the manifest required by `main.rb` and the test helper.

Dispatch walks `Service.subclasses`, so a new service must not match a host another service owns;
`test/services_test.rb` asserts that each source URL matches exactly one service.

## Extraction

- URLs inside inline code, multi-backtick code, and fenced code blocks are not extracted.
- Spoilers are paired left to right; a URL is spoilered when it starts inside a `||…||` span,
  including across newlines. A fixed URL that occurs both inside and outside a spoiler is spoilered,
  so a spoilered link is never leaked. Unmatched delimiters create no span.
- Trailing punctuation is stripped from each match.

## Reply Lifecycle

- At most one fixed reply exists per original message while its record is retained. It is enforced
  by the unique index on `Message#original_message_id`, and `Handlers` skips any message that already
  has a record. Once the record is forgotten (`RETENTION_DAYS`), edits to that message are dropped
  outright, so a second reply is never posted and the surviving reply stays even if the link is gone.
- The bot suppresses the original message's embeds and replies with each distinct fixed link, one per
  line. Reply mentions are disabled (`replied_user: false`), so fixing a link never pings its author.
- Editing the original re-suppresses its embeds and re-syncs the reply: a changed link edits the reply
  in place, removing the link deletes the reply and its record, and adding one posts a reply.
- Deleting the original deletes the fixed reply and its record; deleting the fixed reply drops the
  orphaned record.
- If the fixed reply no longer exists when an edit tries to update it, the record is dropped and a new
  reply is posted.
- Messages authored by bots, including this one, are ignored so bot-to-bot traffic cannot loop.
- Event handling is serialized, so a create and an edit racing on the same message cannot post two
  replies.

## Reply Content

Discord caps message content at 2000 characters. `ReplyContent` keeps complete links until the next
one would exceed the limit, drops the remainder with a warning, and truncates a single oversized link
so the reply is never empty. A record is still written for a truncated reply.

## Invariants

- `fixed_message_id` always refers to the bot's reply and survives edits, so the record never needs
  re-pointing.
- Reply, edit, and delete failures are logged (and unexpected ones reported to Sentry) but never raise
  out of a handler. A failed Discord delete still destroys the local record.
