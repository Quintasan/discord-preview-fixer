#! /usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
Bundler.require(:default)
require_relative 'lib/sentry'
require_relative 'lib/services'
require_relative 'lib/link_fixer'
require_relative 'lib/health'
require_relative 'lib/message'
require_relative 'lib/pruner'
require_relative 'lib/handlers'

BOT = Discordrb::Bot.new(token: ENV.fetch('DISCORD_PREVIEW_FIXER_TOKEN'))

SemanticLogger.application = 'Discord Preview Fixer'
SemanticLogger.environment = ENV.fetch('SENTRY_ENVIRONMENT', nil)
SemanticLogger.add_appender(io: $stdout, formatter: :json)
LOGGER = SemanticLogger['bot']

RETENTION_SECONDS = Integer(ENV.fetch('RETENTION_DAYS', 30)) * 24 * 60 * 60
# Hourly keeps the stale set at about PRUNE_INTERVAL / RETENTION_SECONDS of the
# window, which is what makes the created_at index pay off: the pass never scans
# more than a small slice of the table, however large the table gets.
PRUNE_INTERVAL = 60 * 60

HANDLERS = Handlers.new(logger: LOGGER, sentry: Sentry, retention_seconds: RETENTION_SECONDS)

BOT.message(contains: LinkFixer::HTTP_REGEX) do |event|
  HANDLERS.on_message(event)
end

BOT.message_edit do |event|
  HANDLERS.on_message_edit(event)
end

BOT.message_delete do |event|
  HANDLERS.on_message_delete(event)
end

LOGGER.info('Starting Discord Preview Fixer')
LOGGER.info('Supported services', services: Service.subclasses.map(&:name))

# The DB only drops a record when the original message's deletion is observed,
# so anything older than the retention window is forgotten in case the bot was
# offline. Forgetting never touches Discord, so it needs no gateway connection.
Thread.new do
  loop do
    count = Pruner.run(older_than: Time.now - RETENTION_SECONDS)
    LOGGER.info('Forgot stale message records', count:) if count.positive?
    sleep PRUNE_INTERVAL
  rescue StandardError => e
    LOGGER.error('Failed to prune stale message records', error: e.message)
    sleep PRUNE_INTERVAL
  end
end

# Discordrb reconnects on its own, but a process that stays disconnected is
# still "running" as far as the container runtime is concerned. Stop the bot
# so the restart policy can replace it.
WATCHDOG_GRACE = Integer(ENV.fetch('WATCHDOG_GRACE_SECONDS', 300))
WATCHDOG_INTERVAL = 15

Thread.new do
  disconnected_since = nil
  loop do
    if BOT.connected?
      disconnected_since = nil
    else
      disconnected_since ||= Time.now
      if Time.now - disconnected_since >= WATCHDOG_GRACE
        LOGGER.error('Bot disconnected too long; shutting down for restart')
        BOT.stop
        break
      end
    end
    sleep WATCHDOG_INTERVAL
  end
rescue StandardError => e
  LOGGER.error('Watchdog failed', error: e.message)
end

health_server = begin
  HealthServer.start(bot: BOT, logger: LOGGER)
rescue StandardError => e
  LOGGER.warn('Failed to start health server', error: e.message)
  nil
end

# Trap handlers run in a restricted context, so only flip a flag there and let
# a normal thread stop the bot and run the ensure block below.
shutdown = false
trap('INT') { shutdown = true }
trap('TERM') { shutdown = true }

Thread.new do
  sleep 0.5 until shutdown
  LOGGER.info('Shutting down')
  BOT.stop
rescue StandardError => e
  LOGGER.error('Failed to stop bot', error: e.message)
end

begin
  BOT.run unless shutdown
ensure
  health_server&.stop
  DB.disconnect
end
