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

URI_REGEX = URI::DEFAULT_PARSER.make_regexp

BOT.message(contains: URI_REGEX) do |event|
  next unless event.server.id == 691_315_598_474_477_612

  message = event.message.to_s

  uri_in_message = message.match(URI_REGEX).to_s
  uri = URI.parse(uri_in_message)

  fixed_link = Service.subclasses.filter_map { |k| k.fix_link(uri) }.first

  next unless fixed_link

  fixed_link = "|| #{fixed_link} ||" if message.match?(/\|\|.*\|\|/)

  LOGGER.info(user: event.message.author.display_name, fixed_link: fixed_link)

  event.message.suppress_embeds
  response = event.respond(fixed_link, false, nil, nil, nil, event.message)

  BOT.add_await!(Discordrb::Events::MessageDeleteEvent, timeout: 30) do |delete_event|
    LOGGER.info(event: 'message_delete', original_message_id: delete_event.id)
    response.delete if event.message.id == delete_event.id
  end
end

LOGGER.info { "Started Discord Link Expander at #{Time.now.strftime('%Y-%m-%d-%H:%M:%S')}" }
LOGGER.info { "Supported services: #{Service.subclasses.map(&:name).join(', ')}" }
BOT.run
