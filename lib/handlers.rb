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
    return if ignored?(event)

    fixed_links = LinkFixer.fix(event.message.content)
    return if fixed_links.empty?
    return if Message.first(original_message_id: event.message.id)

    post_fixed_reply(event, fixed_links)
  end

  # The message was edited, so the fixed reply is created, updated, or removed
  # to match the new content.
  def on_message_edit(event)
    return if ignored?(event)

    record = Message.first(original_message_id: event.message.id)
    fixed_links = LinkFixer.fix(event.message.content)

    if fixed_links.empty?
      discard_fixed_reply(event.channel, record, event: 'message_edit')
    elsif record
      update_fixed_reply(event.channel, record, fixed_links)
    else
      post_fixed_reply(event, fixed_links)
    end
  end

  def on_message_delete(event)
    record = Message.first(original_message_id: event.id)
    discard_fixed_reply(event.channel, record, event: 'message_delete')
    destroy_orphaned_record(event)
  end

  private

  # Ignore bots (including this one) so bot-to-bot traffic cannot loop.
  def ignored?(event)
    event.message.author.bot_account?
  end

  def suppress_embeds(message)
    message.suppress_embeds
  rescue StandardError => e
    @logger.warn('Failed to suppress embeds', error: e.message)
  end

  def post_fixed_reply(event, fixed_links)
    reply_content = fixed_links.join("\n")
    @logger.info('Fixed link', user: event.message.author.display_name, fixed_link: reply_content)

    suppress_embeds(event.message)
    reply(event, reply_content)
  end

  def update_fixed_reply(channel, record, fixed_links)
    reply_content = fixed_links.join("\n")
    channel.load_message(record.fixed_message_id).edit(reply_content)
    @logger.info('Updated fixed link', fixed_message_id: record.fixed_message_id, fixed_link: reply_content)
  rescue StandardError => e
    @logger.error('Failed to update fixed link', error: e.message)
    @sentry.capture_exception(e)
  end

  def reply(event, reply_content)
    response = event.respond(reply_content, false, nil, nil, false, event.message)
    Message.dataset.insert_conflict(target: :original_message_id).insert(
      original_message_id: event.message.id,
      fixed_message_id: response.id
    )
  rescue StandardError => e
    @logger.error('Failed to reply with fixed link', error: e.message, backtrace: e.backtrace&.first(5))
    @sentry.capture_exception(e)
  end

  def discard_fixed_reply(channel, record, event:)
    return unless record

    @logger.info('Removed message with fixed link', event: event, original_message_id: record.original_message_id)
    begin
      channel.delete_message(record.fixed_message_id)
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
