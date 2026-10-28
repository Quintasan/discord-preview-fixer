# Discord Preview Fixer

This is a simple Discord bot that scans messages for links to supported services, removes the preview from them and posts a link to a better preview service. It keeps that reply in sync when the original message is edited, and removes it when the original is deleted.

| Service  | Replacement   | Notes                                                  |
|----------|---------------|--------------------------------------------------------|
| Twitter  | vxtwitter.com | Also converts x.com and mobile.twitter.com links       |
| Pixiv    | phixiv.net    |                                                        |
| Reddit   | rxddit.com    | Also converts old/new/np/i.reddit.com links            |
| AmiAmi   | figurki.harvestasha.org    |                                            |
| Instagram| eeinstagram.com    | Also converts m.instagram.com and instagr.am links |
| TikTok   | tnktok.com    |                                                        |

It keeps the fixed reply in sync when the original message is edited (including re-suppressing its
embed), removes it when the original is deleted, and does not ping the original author. Links inside
inline or fenced code are left alone, and spoilers are preserved per link.

## How to use

### Public instance

Ideally, first create a role for the bot, then add that role to channels you want the bot to handle.

You can invite the bot to your server by using [this link](https://discord.com/api/oauth2/authorize?client_id=1162716486020890634&permissions=377957149696&scope=bot). Once the bot has joined, assign it the role you created.

There are 0 guarantees made about the bot working at all times. I maintain the server for my own purposes and if the bot dies then it's dead until I restart it.

Alternatively, you can self-host the bot. To do this, you need an application with a bot. Follow the [Discord Developer docs](https://discord.com/developers/docs/getting-started) to set things up.

The permissions needed by the bot are:

* Read Messages/View channels
* Send Messages
* Send Messages in Threads
* Manage Messages
* Embed Links

If I missed something, or some permissions are not necessary then please let me know.

### Manual install

0. You need Ruby 4.0.9 or later
1. Clone this repository
2. `bundle install --jobs=$(nproc)`
3. `echo "DISCORD_PREVIEW_FIXER_TOKEN=<your Discord bot token here>" > .env`
4. `ruby main.rb`

### Docker Compose

0. Make sure you have Docker and Docker Compose installed
1. Clone this repository
2. `echo "DISCORD_PREVIEW_FIXER_TOKEN=<your Discord bot token here>" > .env`
3. `docker compose pull`
4. `docker compose up -d`

Alternatively you can build the image yourself - run `docker compose build` instead of `docker compose pull`.

The container runs a health check against `http://127.0.0.1:8080/healthz` (port configurable via the `HEALTHCHECK_PORT` environment variable). The bot's status shows as `healthy` in `docker ps` only while it is connected to Discord; it reports `unhealthy` while starting up or if the gateway connection drops.

## Configuration

| Variable | Default | Purpose |
|----------|---------|---------|
| `DISCORD_PREVIEW_FIXER_TOKEN` | required | Discord bot token |
| `SENTRY_DSN` | unset | Sentry error reporting; disabled when unset |
| `SENTRY_ENVIRONMENT` | unset | Sentry and logger environment |
| `DB_PATH` | `messages.db` | SQLite database path |
| `HEALTHCHECK_PORT` | `8080` | Health endpoint port |
| `RETENTION_DAYS` | `30` | Days a message record is remembered before it is forgotten; edits to older messages are ignored |
| `WATCHDOG_GRACE_SECONDS` | `300` | Disconnect time before the bot restarts |

Pruning runs hourly and only forgets records — it never deletes the bot's fixed replies, so a
retention pass makes no Discord calls and can run before the bot is online. Replies to messages
deleted while the bot was offline stay in their channels, and an edit to a message older than
`RETENTION_DAYS` is ignored so a second reply is never posted.

`.env` is loaded before Sentry and the database are initialized, so `SENTRY_DSN` and `DB_PATH` can be
set there for manual installs.
