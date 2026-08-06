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
Bundler.require(:default)
BOT = Discordrb::Bot.new(token: ENV.fetch('DISCORD_PREVIEW_FIXER_TOKEN'))

SemanticLogger.application = 'Discord Preview Fixer'
SemanticLogger.environment = ENV.fetch('SENTRY_ENVIRONMENT', nil)
SemanticLogger.add_appender(io: $stdout, formatter: :json)
LOGGER = SemanticLogger['bot']

BOT.message(contains: LinkFixer::HTTP_REGEX) do |event|
  message = event.message.content
  fixed_links = LinkFixer.fix(message)

  next if fixed_links.empty?

  reply_content = fixed_links.join("\n")
  LOGGER.info('Fixed link', user: event.message.author.display_name, fixed_link: reply_content)

  begin
    event.message.suppress_embeds
  rescue StandardError => e
    LOGGER.warn('Failed to suppress embeds', error: e.message)
  end

  begin
    response = event.respond(reply_content, false, nil, nil, false, event.message)
    Message.create(original_message_id: event.message.id, fixed_message_id: response.id)
  rescue StandardError => e
    LOGGER.error('Failed to reply with fixed link', error: e.message, backtrace: e.backtrace&.first(5))
    Sentry.capture_exception(e)
  end
end

BOT.message_delete do |event|
  record = Message.first(original_message_id: event.id)
  if record
    LOGGER.info('Removed message with fixed link', event: 'message_delete', original_message_id: event.id)
    begin
      event.channel.delete_message(record.fixed_message_id)
    rescue StandardError => e
      LOGGER.error('Failed to delete fixed link message', error: e.message)
    ensure
      record.destroy
    end
  end

  # The fixed reply itself was deleted, so drop the now-orphaned record.
  orphan = Message.first(fixed_message_id: event.id)
  next unless orphan

  LOGGER.info('Removed orphaned fixed link record', event: 'message_delete', fixed_message_id: event.id)
  orphan.destroy
end

LOGGER.info('Starting Discord Link Expander')
LOGGER.info('Supported services', services: Service.subclasses.map(&:name))

begin
  HealthServer.start(bot: BOT, logger: LOGGER)
rescue StandardError => e
  LOGGER.warn('Failed to start health server', error: e.message)
end

BOT.run
