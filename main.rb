#! /usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
Bundler.require(:default)

BOT = Discordrb::Bot.new(token: ENV.fetch('DISCORD_PREVIEW_FIXER_TOKEN'))
LOGGER = TTY::Logger.new
PIXIV_REGEX = %r{https?://(?<www>www.)?(?<domain>pixiv.net)/\S+/artworks/\d+}i
TWITTER_REGEX = %r{https?://(?<www>www.)?(?<domain>twitter.com)/(?<username>\S+)/status/(?<post_id>\d+)}i

def replace_domain(link, original_domain, new_domain)
  link.gsub(original_domain, new_domain)
end

BOT.message(contains: PIXIV_REGEX) do |event|
  old_link = event.message.to_s.match(PIXIV_REGEX).to_s
  new_link = replace_domain(
    old_link,
    'pixiv',
    'phixiv'
  )
  LOGGER.info(service: 'pixiv', user: event.message.author.display_name, link: old_link, new_link: new_link)
  event.respond(new_link, false, nil, nil, nil, event.message)
  event.message.suppress_embeds
end

BOT.message(contains: TWITTER_REGEX) do |event|
  old_link = event.message.to_s.match(TWITTER_REGEX).to_s
  new_link = replace_domain(
    old_link,
    'twitter',
    'vxtwitter'
  )
  LOGGER.info(service: 'twitter', user: event.message.author.display_name, link: old_link, new_link: new_link)
  event.respond(new_link, false, nil, nil, nil, event.message)
  event.message.suppress_embeds
end

LOGGER.info { "Started Discord Link Expander at #{Time.now.strftime('%Y-%m-%d-%H:%M:%S')}" }
BOT.run
