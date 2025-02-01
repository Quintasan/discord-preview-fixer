#! /usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require_relative 'lib/pixiv'
require_relative 'lib/amiami'
Bundler.require(:default)
BOT = Discordrb::Bot.new(token: ENV.fetch('DISCORD_PREVIEW_FIXER_TOKEN'))
LOGGER = TTY::Logger.new
REDDIT_REGEX = %r{https?://(?<subdomain>www.|old.)?(?<tld>reddit.com)(?<rest>/\S*)}i
TIKTOK_REGEX = %r{https?://(?<subdomain>www.|vm.)?(?<tld>tiktok.com)(?<rest>/\S*)}i

BOT.message(contains: AmiAmi::REGEX) do |event|
  fixed_link = AmiAmi.fix_link(event)
  LOGGER.info(service: 'amiami', user: event.message.author.display_name, fixed_link: fixed_link)
  event.respond(fixed_link, false, nil, nil, nil, event.message)
  event.message.suppress_embeds
end

BOT.message(contains: Pixiv::REGEX) do |event|
  fixed_link = Pixiv.fix_link(event)
  LOGGER.info(service: 'pixiv', user: event.message.author.display_name, fixed_link: fixed_link)
  event.respond(fixed_link, false, nil, nil, nil, event.message)
  event.message.suppress_embeds
end

BOT.message(contains: Twitter::REGEX) do |event|
  fixed_link = Twitter.fix_link(event)
  LOGGER.info(service: 'twitter', user: event.message.author.display_name, fixed_link: fixed_link)
  event.respond(fixed_link, false, nil, nil, nil, event.message)
  event.message.suppress_embeds
end

BOT.message(contains: REDDIT_REGEX) do |event|
  old_link = event.message.to_s.match(REDDIT_REGEX).to_s
  new_link = replace_domain(
    old_link,
    'reddit',
    'rxddit'
  )
  LOGGER.info(service: 'twitter', user: event.message.author.display_name, link: old_link, new_link: new_link)
  event.respond(new_link, false, nil, nil, nil, event.message)
  event.message.suppress_embeds
end

BOT.message(contains: TIKTOK_REGEX) do |event|
  old_link = event.message.to_s.match(TIKTOK_REGEX).to_s
  new_link = replace_domain(
    old_link,
    'tiktok',
    'vxtiktok'
  )
  LOGGER.info(service: 'twitter', user: event.message.author.display_name, link: old_link, new_link: new_link)
  event.respond(new_link, false, nil, nil, nil, event.message)
  event.message.suppress_embeds
end

LOGGER.info { "Started Discord Link Expander at #{Time.now.strftime('%Y-%m-%d-%H:%M:%S')}" }
BOT.run
