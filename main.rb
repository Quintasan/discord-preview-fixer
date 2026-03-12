#! /usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require_relative 'lib/sentry'
require_relative 'lib/pixiv'
require_relative 'lib/amiami'
require_relative 'lib/twitter'
require_relative 'lib/reddit'
require_relative 'lib/instagram'
Bundler.require(:default)
BOT = Discordrb::Bot.new(token: ENV.fetch('DISCORD_PREVIEW_FIXER_TOKEN'))

SemanticLogger.application = 'Discord Preview Fixer'
SemanticLogger.environment = ENV.fetch('SENTRY_ENVIRONMENT', nil)
SemanticLogger.add_appender(io: $stdout, formatter: :json)
LOGGER = SemanticLogger['bot']

HTTP_REGEX = URI::DEFAULT_PARSER.make_regexp(%w[http https])

BOT.message(contains: HTTP_REGEX) do |event|
  message = event.message.to_s

  uri_in_message = message.match(HTTP_REGEX).to_s
  uri = URI.parse(uri_in_message)

  fixed_link = Service.subclasses.filter_map { |k| k.fix_link(uri) }.first

  next unless fixed_link

  fixed_link = "|| #{fixed_link} ||" if message.match?(/\|\|.*\|\|/)

  LOGGER.info(user: event.message.author.display_name, fixed_link: fixed_link)

  event.message.suppress_embeds
  response = event.respond(fixed_link, false, nil, nil, false, event.message)

  BOT.add_await!(Discordrb::Events::MessageDeleteEvent, timeout: 30) do |delete_event|
    LOGGER.info(event: 'message_delete', original_message_id: delete_event.id)
    response.delete if event.message.id == delete_event.id
  end
end

LOGGER.info('Starting Discord Link Expander')
LOGGER.info('Supported services', services: Service.subclasses.map(&:name))
BOT.run
