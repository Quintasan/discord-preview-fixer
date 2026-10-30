---
description: Discordrb 3.8 API notes for the events and methods this bot relies on.
read_if: Adding or changing Discord event handling, message edits, or bot filtering.
---

# Discordrb Notes

Verified against discordrb 3.8.

## Events

- `message` — a new message. Register with `contains:` to pre-filter; the bot uses
  `LinkFixer::HTTP_REGEX`.
- `message_edit` — raised for every `MESSAGE_UPDATE` except this bot's own. The payload's `author` is
  the message's *author*, never the editor, so a bot PATCH of someone else's message (embed
  suppression, pinning) arrives as a `message_edit` with the human author and cannot be filtered by
  `bot_account?`. It is not proof of a content edit.
- `message_update` — raised for every `MESSAGE_UPDATE`, including embed-only changes that carry no
  author. Do not use it to detect content edits; it fires far more often than `message_edit`.
- `message_delete` — `event.id` is the deleted message ID and `event.channel` its channel.

`MessageEvent` exposes `#message` and delegates `#author`, `#channel`, and `#content`. It does not
expose `#id`; read `event.message.id`.

Each handler runs on its own thread (`Bot#call_event`), and discordrb rescues `StandardError` into its
own logger. Any failure that must reach Sentry has to be rescued and reported inside the handler.

## Replying and mentions

`Message#respond(content, tts, embed, attachments, allowed_mentions, message_reference, ...)`.
`allowed_mentions: false` is translated to `{ parse: [] }`, but Discord still pings the replied-to
author because `replied_user` defaults to `true`. Pass `{ parse: [], replied_user: false }`, or use
`Message#reply!`, which sets it from `mention_user: false`.

## Editing a reply

`Channel` has `delete_message` but no `edit_message`. Load the message and edit it:

```ruby
channel.load_message(message_id).edit(new_content)
```

`Channel#load_message` rescues `UnknownMessage` and returns `nil` instead of raising, so a deleted
target surfaces as `NoMethodError` on the chained `.edit`, not as `UnknownMessage`. Check for `nil`
before editing. `Discordrb::Errors::UnknownMessage` (code 10008) is raised by `delete_message`, or by
an edit whose target disappears between the load and the PATCH.

## Embed suppression and `Message#edit`

- `Message#suppress_embeds` ORs `SUPPRESS_EMBEDS` (`1 << 2`) onto the cached flags and PATCHes with
  `content: :undef`, so it never disturbs the body. `message.suppress_embeds?` reads the state. The
  method has no idempotency check: calling it twice sends two PATCHes, the second an empty flag update.
  That PATCH echoes back as `MESSAGE_UPDATE`, so call it only when `suppress_embeds?` is false.
- `MESSAGE_UPDATE` is a full message object, not a partial one (Discord API docs change, October
  2024), so `content`, `author`, and `flags` are all present. `Message` defaults `flags` to `0` when
  the key is missing, which silently disables a `suppress_embeds?` guard.
- `Message#edit(new_content, new_embeds = nil, new_components = nil, flags = 0)` defaults `flags` to
  `0`, and `API::Channel.edit_message` serializes `flags` (it only drops `:undef`). A bare
  `.edit(content)` therefore sends `"flags": 0`, clearing `SUPPRESS_EMBEDS` on the edited message.
  Pass `message.flags | (1 << 2)` explicitly to edit content while keeping suppression.
- Suppression is a flag asserted on edit, not an immutable property, so a fixer may re-suppress after
  a real author edit, but only when the flag is not already set.

## Message length

`content` is capped at 2000 characters by the REST API for bots, users, and webhooks alike. Building
one reply by joining link lines can exceed that and fails with HTTP 400 (Invalid Form Body), so long
result sets need chunking or a length guard. This bot keeps complete links up to the limit, drops the
rest, and truncates a single oversized link (`ReplyContent`).

## Bot detection

The predicate for "this author is a bot" is `User#bot_account?` (aliased from `#bot_account`); there
is no `#bot?`. `#current_bot?` is true only for this bot, so it cannot filter other bots.
