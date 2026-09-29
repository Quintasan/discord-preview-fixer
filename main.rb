#! /usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require_relative 'lib/sentry'
require_relative 'lib/pixiv'
require_relative 'lib/amiami'
require_relative 'lib/twitter'
require_relative 'lib/reddit'
require_relative 'lib/instagram'
require_relative 'lib/tiktok'
require_relative 'lib/link_fixer'
require_relative 'lib/health'
require_relative 'lib/message'
require_relative 'lib/handlers'
Bundler.require(:default)
BOT = Discordrb::Bot.new(token: ENV.fetch('DISCORD_PREVIEW_FIXER_TOKEN'))

SemanticLogger.application = 'Discord Preview Fixer'
SemanticLogger.environment = ENV.fetch('SENTRY_ENVIRONMENT', nil)
SemanticLogger.add_appender(io: $stdout, formatter: :json)
LOGGER = SemanticLogger['bot']

HANDLERS = Handlers.new(logger: LOGGER, sentry: Sentry)

BOT.message(contains: LinkFixer::HTTP_REGEX) do |event|
  HANDLERS.on_message(event)
end

BOT.message_delete do |event|
  HANDLERS.on_message_delete(event)
end

LOGGER.info('Starting Discord Link Expander')
LOGGER.info('Supported services', services: Service.subclasses.map(&:name))

begin
  HealthServer.start(bot: BOT, logger: LOGGER)
rescue StandardError => e
  LOGGER.warn('Failed to start health server', error: e.message)
end

BOT.run
