# frozen_string_literal: true

require 'discordrb/errors'
require_relative 'handler_support'
require_relative 'link_fixer'
require_relative 'message'
require_relative 'reply_content'

# Discord event handlers, extracted from main.rb so they can be unit-tested
# with fake event objects instead of a live bot.
class Handlers
  include HandlerSupport

  ALLOWED_MENTIONS = { parse: [], replied_user: false }.freeze

  def initialize(logger:, sentry:, retention_seconds:)
    @logger = logger
    @sentry = sentry
    @retention_seconds = retention_seconds
    @mutex = Mutex.new
  end

  def on_message(event)
    guard('message') do
      next if ignored?(event)

      fixed_links = LinkFixer.fix(event.message.content)
      next if fixed_links.empty?
      next if Message.first(original_message_id: event.message.id)

      post_fixed_reply(event, fixed_links)
    end
  end

  # The message was edited, so the fixed reply is created, updated, or removed
  # to match the new content. Edits to messages past the retention window are
  # ignored: their record is forgotten, so fixing them would post a duplicate.
  def on_message_edit(event)
    guard('message_edit') do
      next if ignored?(event)
      next if forgotten?(event.message)

      update_for_edit(event)
    end
  end

  def on_message_delete(event)
    guard('message_delete') do
      record = Message.first(original_message_id: event.id)
      discard_fixed_reply(event.channel, record, event: 'message_delete')
      destroy_orphaned_record(event)
    end
  end

  private

  def forgotten?(message) = message.timestamp < Time.now - @retention_seconds

  def update_for_edit(event)
    record = Message.first(original_message_id: event.message.id)
    fixed_links = LinkFixer.fix(event.message.content)
    return discard_fixed_reply(event.channel, record, event: 'message_edit') if fixed_links.empty?
    return post_fixed_reply(event, fixed_links) unless record

    suppress_embeds(event.message)
    update_fixed_reply(event, record, fixed_links)
  end

  def post_fixed_reply(event, fixed_links)
    reply_content = ReplyContent.build(fixed_links, message_id: event.message.id, logger: @logger)
    @logger.info(
      'Fixed link',
      user: event.message.author.display_name,
      message_id: event.message.id,
      channel_id: event.channel.id,
      fixed_link: reply_content
    )
    suppress_embeds(event.message)
    reply(event, reply_content)
  end

  def update_fixed_reply(event, record, fixed_links)
    reply_content = ReplyContent.build(fixed_links, message_id: record.original_message_id, logger: @logger)
    event.channel.load_message(record.fixed_message_id).edit(reply_content)
    @logger.info('Updated fixed link', fixed_message_id: record.fixed_message_id, fixed_link: reply_content)
  rescue Discordrb::Errors::UnknownMessage
    repost_fixed_reply(event, record, fixed_links)
  rescue StandardError => e
    @logger.error('Failed to update fixed link', error: e.message)
    @sentry.capture_exception(e) unless expected_error?(e)
  end

  def repost_fixed_reply(event, record, fixed_links)
    @logger.info('Fixed link message is gone; posting a new one', original_message_id: record.original_message_id)
    record.destroy
    post_fixed_reply(event, fixed_links)
  end

  def reply(event, reply_content)
    response = event.respond(reply_content, false, nil, nil, ALLOWED_MENTIONS, event.message)
    Message.record(
      original_message_id: event.message.id,
      fixed_message_id: response.id,
      channel_id: event.channel.id
    )
  rescue StandardError => e
    @logger.error('Failed to reply with fixed link', error: e.message, backtrace: e.backtrace&.first(5))
    @sentry.capture_exception(e) unless expected_error?(e)
  end

  def discard_fixed_reply(channel, record, event:)
    return unless record

    @logger.info('Removed message with fixed link', event: event, original_message_id: record.original_message_id)
    delete_fixed_reply(channel, record)
  ensure
    record&.destroy
  end

  def delete_fixed_reply(channel, record)
    channel.delete_message(record.fixed_message_id)
  rescue Discordrb::Errors::UnknownMessage
    nil # already gone
  rescue StandardError => e
    @logger.error('Failed to delete fixed link message', error: e.message)
  end

  # The fixed reply itself was deleted, so drop the now-orphaned record.
  def destroy_orphaned_record(event)
    orphan = Message.first(fixed_message_id: event.id)
    return unless orphan

    @logger.info('Removed orphaned fixed link record', event: 'message_delete', fixed_message_id: event.id)
    orphan.destroy
  end
end
