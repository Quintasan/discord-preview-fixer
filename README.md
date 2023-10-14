# Discord Preview Fixer

This is a simple Discord bot that scans messaages for links to Pixiv/Twitter, removes the preview from them and posts a link to a more better preview service.

| Service  | Replacement   | Notes                            |
|----------|---------------|----------------------------------|
| Twtitter | vxtwitter.com | Will convert x.com links as well |
| Pixiv    | phixiv.net    |                                  |
| Tiktok   | vxtiktok.com  |                                  |
| Reddit   | rxddit.com    |                                  |

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

0. You need Ruby 2.7 or later
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
