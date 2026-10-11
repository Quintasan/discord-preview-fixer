---
description: Discordrb 3.8 API notes for the events and methods this bot relies on.
read_if: Adding or changing Discord event handling, message edits, or bot filtering.
---

# Discordrb Notes

Verified against discordrb 3.8.

## Events

- `message` — a new message. Register with `contains:` to pre-filter; the bot uses
  `LinkFixer::HTTP_REGEX`.
- `message_edit` — raised only when an edit is attributable to an author, i.e. a real content edit.
- `message_update` — raised for every `MESSAGE_UPDATE`, including embed-only changes that carry no
  author. Do not use it to detect content edits; it fires far more often than `message_edit`.
- `message_delete` — `event.id` is the deleted message ID and `event.channel` its channel.

`MessageEvent` exposes `#message` and delegates `#author`, `#channel`, and `#content`. It does not
expose `#id`; read `event.message.id`.

## Editing a reply

`Channel` has `delete_message` but no `edit_message`. Load the message and edit it:

```ruby
channel.load_message(message_id).edit(new_content)
```

## Bot detection

The predicate for "this author is a bot" is `User#bot_account?` (aliased from `#bot_account`); there
is no `#bot?`. `#current_bot?` is true only for this bot, so it cannot filter other bots.
