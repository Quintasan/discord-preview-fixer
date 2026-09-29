# frozen_string_literal: true

require_relative 'link_fixer'
require_relative 'message'

# Discord event handlers, extracted from main.rb so they can be unit-tested
# with fake event objects instead of a live bot.
class Handlers
  def initialize(logger:, sentry:)
    @logger = logger
    @sentry = sentry
  end

  def on_message(event)
    fixed_links = LinkFixer.fix(event.message.content)
    return if fixed_links.empty?

    reply_content = fixed_links.join("\n")
    @logger.info('Fixed link', user: event.message.author.display_name, fixed_link: reply_content)

    suppress_embeds(event.message)
    reply(event, reply_content)
  end

  def on_message_delete(event)
    delete_fixed_reply(event)
    destroy_orphaned_record(event)
  end

  private

  def suppress_embeds(message)
    message.suppress_embeds
  rescue StandardError => e
    @logger.warn('Failed to suppress embeds', error: e.message)
  end

  def reply(event, reply_content)
    response = event.respond(reply_content, false, nil, nil, false, event.message)
    Message.create(original_message_id: event.message.id, fixed_message_id: response.id)
  rescue StandardError => e
    @logger.error('Failed to reply with fixed link', error: e.message, backtrace: e.backtrace&.first(5))
    @sentry.capture_exception(e)
  end

  def delete_fixed_reply(event)
    record = Message.first(original_message_id: event.id)
    return unless record

    @logger.info('Removed message with fixed link', event: 'message_delete', original_message_id: event.id)
    begin
      event.channel.delete_message(record.fixed_message_id)
    rescue StandardError => e
      @logger.error('Failed to delete fixed link message', error: e.message)
    ensure
      record.destroy
    end
  end

  # The fixed reply itself was deleted, so drop the now-orphaned record.
  def destroy_orphaned_record(event)
    orphan = Message.first(fixed_message_id: event.id)
    return unless orphan

    @logger.info('Removed orphaned fixed link record', event: 'message_delete', fixed_message_id: event.id)
    orphan.destroy
  end
end
