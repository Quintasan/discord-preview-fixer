# Discord Preview Fixer

This is a simple Discord bot that scans messaages for links to Pixiv/Twitter, removes the preview from them and posts a link to a more better preview service.

| Service  | Replacement   | Notes                            |
|----------|---------------|----------------------------------|
| Twtitter | vxtwitter.com | Will convert x.com links as well |
| Pixiv    | phixiv.net    |                                  |

## How to use

### Manual installed

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
