#! /usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require_relative 'lib/pixiv'
require_relative 'lib/amiami'
require_relative 'lib/twitter'
require_relative 'lib/reddit'
require_relative 'lib/tiktok'
Bundler.require(:default)
BOT = Discordrb::Bot.new(token: ENV.fetch('DISCORD_PREVIEW_FIXER_TOKEN'))
LOGGER = TTY::Logger.new

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

BOT.message(contains: Reddit::REGEX) do |event|
  fixed_link = TikTok.fix_link(event)
  LOGGER.info(service: 'reddit', user: event.message.author.display_name, fixed_link: fixed_link)
  event.respond(new_link, false, nil, nil, nil, event.message)
  event.message.suppress_embeds
end

BOT.message(contains: TikTok::REGEX) do |event|
  fixed_link = TikTok.fix_link(event)
  LOGGER.info(service: 'tiktok', user: event.message.author.display_name, fixed_link: fixed_link)
  event.respond(fixed_link, false, nil, nil, nil, event.message)
  event.message.suppress_embeds
end

LOGGER.info { "Started Discord Link Expander at #{Time.now.strftime('%Y-%m-%d-%H:%M:%S')}" }
BOT.run
