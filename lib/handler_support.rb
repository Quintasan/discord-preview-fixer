# frozen_string_literal: true

require 'discordrb/errors'

# Shared behavior for Handlers: serialized event handling with Sentry reporting
# for unexpected failures, bot filtering, and embed suppression. Handlers
# supplies @mutex, @logger, and @sentry.
module HandlerSupport
  EXPECTED_ERRORS = [Discordrb::Errors::NoPermission, Discordrb::Errors::UnknownMessage].freeze

  private

  def guard(context, &)
    @mutex.synchronize(&)
  rescue StandardError => e
    @logger.error('Handler failed', event: context, error: e.message)
    @sentry.capture_exception(e) unless expected_error?(e)
  end

  def expected_error?(error)
    EXPECTED_ERRORS.any? { |klass| error.is_a?(klass) }
  end

  # Ignore bots (including this one) so bot-to-bot traffic cannot loop.
  def ignored?(event)
    event.message.author.bot_account?
  end

  # Suppression is idempotent on purpose: the PATCH echoes back as a message
  # update authored by the original author, so suppressing on edit would make
  # every fixed message re-suppress itself.
  def suppress_embeds(message)
    return if message.suppress_embeds?

    message.suppress_embeds
  rescue StandardError => e
    @logger.warn('Failed to suppress embeds', error: e.message)
  end
end
