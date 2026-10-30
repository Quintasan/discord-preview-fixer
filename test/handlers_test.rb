# frozen_string_literal: true

require_relative 'test_helper'
require 'handlers'

class HandlersTest < Minitest::Test
  Author = Struct.new(:display_name, :bot_account) do
    alias_method :bot_account?, :bot_account
  end
  Response = Struct.new(:id)

  class FakeLogger
    attr_reader :entries

    def initialize
      @entries = []
    end

    %i[info warn error debug].each do |level|
      define_method(level) { |message, **context| @entries << [level, message, context] }
    end

    def logged?(level, message)
      @entries.any? { |entry_level, entry_message, _| entry_level == level && entry_message == message }
    end
  end

  RETENTION_SECONDS = 30 * 86_400

  class FakeSentry
    attr_reader :captured

    def initialize
      @captured = []
    end

    def capture_exception(error)
      @captured << error
    end
  end

  # Some exceptions report no backtrace at all (e.g. built by a library).
  class NoBacktraceError < StandardError
    def backtrace
      nil
    end
  end

  class FakeMessage
    SUPPRESS_EMBEDS = 1 << 2

    attr_reader :content, :author, :id, :suppress_calls
    attr_accessor :timestamp, :flags

    def initialize(content:, id: 1000, display_name: 'tester', suppress_error: nil, bot_account: false)
      @content = content
      @id = id
      @author = Author.new(display_name, bot_account)
      @suppress_error = suppress_error
      @suppress_calls = 0
      @timestamp = Time.now
      @flags = 0
    end

    # Mirrors discordrb: the PATCH returns a new message carrying the flag, and
    # the receiver keeps its old flags.
    def suppress_embeds
      @suppress_calls += 1
      raise @suppress_error if @suppress_error

      echo = self.class.new(content: @content, id: @id, display_name: @author.display_name,
                            bot_account: @author.bot_account)
      echo.flags = @flags | SUPPRESS_EMBEDS
      echo
    end

    def suppress_embeds? = @flags.anybits?(SUPPRESS_EMBEDS)
  end

  class FakeMessageEvent
    attr_reader :message, :responses, :response_args, :channel

    def initialize(message:, response_id: 2000, respond_error: nil, channel: FakeChannel.new)
      @message = message
      @response_id = response_id
      @respond_error = respond_error
      @channel = channel
      @responses = []
      @response_args = []
    end

    def respond(content, *args)
      raise @respond_error if @respond_error

      @responses << content
      @response_args << args
      Response.new(@response_id)
    end
  end

  class FakeChannel
    attr_reader :deleted, :edited, :id

    def initialize(id: 3000, error: nil, load_error: nil, edit_error: nil)
      @id = id
      @deleted = []
      @edited = []
      @error = error
      @load_error = load_error
      @edit_error = edit_error
    end

    def delete_message(id)
      raise @error if @error

      @deleted << id
    end

    def load_message(id)
      raise @load_error if @load_error

      FakeLoadedMessage.new(id: id, channel: self, edit_error: @edit_error)
    end
  end

  class FakeLoadedMessage
    def initialize(id:, channel:, edit_error: nil)
      @id = id
      @channel = channel
      @edit_error = edit_error
    end

    def edit(content)
      raise @edit_error if @edit_error

      @channel.edited << [@id, content]
    end
  end

  class FakeDeleteEvent
    attr_reader :id, :channel

    def initialize(id:, channel: FakeChannel.new)
      @id = id
      @channel = channel
    end
  end

  def setup
    Message.dataset.destroy
    @logger = FakeLogger.new
    @sentry = FakeSentry.new
    @handlers = Handlers.new(logger: @logger, sentry: @sentry, retention_seconds: RETENTION_SECONDS)
  end

  def test_posts_fixed_link_and_suppresses_embeds
    message = FakeMessage.new(content: 'see https://twitter.com/a/status/1')
    event = FakeMessageEvent.new(message:)

    @handlers.on_message(event)

    assert_equal ['https://vxtwitter.com/a/status/1'], event.responses
    assert_equal 1, message.suppress_calls
    assert @logger.logged?(:info, 'Fixed link')
  end

  def test_records_message_for_posted_fixed_link
    message = FakeMessage.new(content: 'see https://twitter.com/a/status/1')
    event = FakeMessageEvent.new(message:)

    @handlers.on_message(event)

    record = Message.first(original_message_id: 1000)

    refute_nil record
    assert_equal 2000, record.fixed_message_id
  end

  def test_ignores_messages_without_supported_links
    message = FakeMessage.new(content: 'nothing to fix here')
    event = FakeMessageEvent.new(message:)

    @handlers.on_message(event)

    assert_empty event.responses
    assert_equal 0, message.suppress_calls
    assert_nil Message.first(original_message_id: 1000)
  end

  def test_replies_even_when_suppress_embeds_fails
    message = FakeMessage.new(
      content: 'https://twitter.com/a/status/1',
      suppress_error: StandardError.new('cannot suppress')
    )
    event = FakeMessageEvent.new(message:)

    @handlers.on_message(event)

    assert_equal ['https://vxtwitter.com/a/status/1'], event.responses
    assert @logger.logged?(:warn, 'Failed to suppress embeds')
  end

  def test_captures_reply_failures
    error = StandardError.new('reply exploded')
    message = FakeMessage.new(content: 'https://twitter.com/a/status/1')
    event = FakeMessageEvent.new(message: message, respond_error: error)

    @handlers.on_message(event)

    assert_equal [error], @sentry.captured
    assert @logger.logged?(:error, 'Failed to reply with fixed link')
    assert_nil Message.first(original_message_id: 1000)
  end

  def test_captures_reply_failures_without_backtrace
    error = NoBacktraceError.new('reply exploded')
    message = FakeMessage.new(content: 'https://twitter.com/a/status/1')
    event = FakeMessageEvent.new(message: message, respond_error: error)

    @handlers.on_message(event)

    assert_equal [error], @sentry.captured
    assert @logger.logged?(:error, 'Failed to reply with fixed link')
  end

  def test_deletes_fixed_reply_and_record
    Message.create(original_message_id: 3000, fixed_message_id: 4000)
    event = FakeDeleteEvent.new(id: 3000)

    @handlers.on_message_delete(event)

    assert_equal [4000], event.channel.deleted
    assert_nil Message.first(original_message_id: 3000)
    assert @logger.logged?(:info, 'Removed message with fixed link')
  end

  def test_destroys_record_when_channel_delete_fails
    Message.create(original_message_id: 3000, fixed_message_id: 4000)
    channel = FakeChannel.new(error: StandardError.new('already gone'))
    event = FakeDeleteEvent.new(id: 3000, channel: channel)

    @handlers.on_message_delete(event)

    assert @logger.logged?(:error, 'Failed to delete fixed link message')
    assert_nil Message.first(original_message_id: 3000)
  end

  def test_removes_orphaned_record_when_fixed_reply_deleted
    Message.create(original_message_id: 3000, fixed_message_id: 4000)
    event = FakeDeleteEvent.new(id: 4000)

    @handlers.on_message_delete(event)

    assert_nil Message.first(fixed_message_id: 4000)
    assert @logger.logged?(:info, 'Removed orphaned fixed link record')
  end

  def test_ignores_deletes_without_matching_record
    event = FakeDeleteEvent.new(id: 9999)

    @handlers.on_message_delete(event)

    assert_empty event.channel.deleted
  end

  def test_ignores_messages_from_bots
    message = FakeMessage.new(content: 'https://twitter.com/a/status/1', bot_account: true)
    event = FakeMessageEvent.new(message:)

    @handlers.on_message(event)

    assert_empty event.responses
    assert_nil Message.first(original_message_id: 1000)
  end

  def test_does_not_reply_twice_for_the_same_message
    message = FakeMessage.new(content: 'https://twitter.com/a/status/1')
    event = FakeMessageEvent.new(message:)

    @handlers.on_message(event)
    @handlers.on_message(event)

    assert_equal ['https://vxtwitter.com/a/status/1'], event.responses
    assert_equal 1, Message.dataset.count
  end

  def test_updates_fixed_reply_when_edited
    Message.create(original_message_id: 1000, fixed_message_id: 2000)
    message = FakeMessage.new(content: 'now https://pixiv.net/en/artworks/1')
    event = FakeMessageEvent.new(message:)

    @handlers.on_message_edit(event)

    assert_equal [[2000, 'https://phixiv.net/en/artworks/1']], event.channel.edited
    assert_empty event.channel.deleted
    assert @logger.logged?(:info, 'Updated fixed link')
  end

  def test_removes_fixed_reply_when_edited_link_is_gone
    Message.create(original_message_id: 1000, fixed_message_id: 2000)
    message = FakeMessage.new(content: 'no links anymore')
    event = FakeMessageEvent.new(message:)

    @handlers.on_message_edit(event)

    assert_equal [2000], event.channel.deleted
    assert_nil Message.first(original_message_id: 1000)
    assert @logger.logged?(:info, 'Removed message with fixed link')
  end

  def test_posts_new_reply_when_edit_adds_a_link
    message = FakeMessage.new(content: 'see https://twitter.com/a/status/1')
    event = FakeMessageEvent.new(message:)

    @handlers.on_message_edit(event)

    assert_equal ['https://vxtwitter.com/a/status/1'], event.responses
    assert_equal 1, message.suppress_calls
    assert Message.first(original_message_id: 1000)
  end

  def test_ignores_edits_without_record_or_link
    message = FakeMessage.new(content: 'no links')
    event = FakeMessageEvent.new(message:)

    @handlers.on_message_edit(event)

    assert_empty event.channel.edited
    assert_empty event.channel.deleted
  end

  def test_ignores_edits_to_messages_past_the_retention_window
    event = FakeMessageEvent.new(message: old_message('see https://twitter.com/a/status/1'))

    @handlers.on_message_edit(event)

    assert_empty event.responses
    assert_empty event.channel.edited
    assert_equal 0, Message.dataset.count
  end

  def test_leaves_an_existing_reply_alone_when_an_old_message_is_edited
    Message.create(original_message_id: 1000, fixed_message_id: 2000)
    event = FakeMessageEvent.new(message: old_message('https://twitter.com/a/status/1'))

    @handlers.on_message_edit(event)

    assert_empty event.channel.edited
    assert Message.first(original_message_id: 1000)
  end

  def test_fixes_edits_inside_the_retention_window
    message = FakeMessage.new(content: 'see https://twitter.com/a/status/1')
    message.timestamp = Time.now - (29 * 86_400)
    event = FakeMessageEvent.new(message:)

    @handlers.on_message_edit(event)

    assert_equal ['https://vxtwitter.com/a/status/1'], event.responses
  end

  def test_ignores_edits_from_bots
    Message.create(original_message_id: 1000, fixed_message_id: 2000)
    message = FakeMessage.new(content: 'https://twitter.com/a/status/1', bot_account: true)
    event = FakeMessageEvent.new(message:)

    @handlers.on_message_edit(event)

    assert_empty event.channel.edited
  end

  def test_captures_fixed_reply_update_failures
    Message.create(original_message_id: 1000, fixed_message_id: 2000)
    channel = FakeChannel.new(edit_error: StandardError.new('edit exploded'))
    message = FakeMessage.new(content: 'https://twitter.com/a/status/1')
    event = FakeMessageEvent.new(message:, channel:)

    @handlers.on_message_edit(event)

    assert_equal 1, @sentry.captured.size
    assert @logger.logged?(:error, 'Failed to update fixed link')
  end

  def test_destroys_record_when_fixed_reply_is_already_gone
    Message.create(original_message_id: 3000, fixed_message_id: 4000)
    channel = FakeChannel.new(error: Discordrb::Errors::UnknownMessage.new('Unknown Message'))
    event = FakeDeleteEvent.new(id: 3000, channel: channel)

    @handlers.on_message_delete(event)

    assert_nil Message.first(original_message_id: 3000)
    refute @logger.logged?(:error, 'Failed to delete fixed link message')
  end

  def test_does_not_capture_expected_update_failures
    Message.create(original_message_id: 1000, fixed_message_id: 2000)
    channel = FakeChannel.new(edit_error: Discordrb::Errors::NoPermission.new('no permission'))
    message = FakeMessage.new(content: 'https://twitter.com/a/status/1')
    event = FakeMessageEvent.new(message:, channel:)

    @handlers.on_message_edit(event)

    assert_empty @sentry.captured
    assert @logger.logged?(:error, 'Failed to update fixed link')
  end

  def test_does_not_capture_expected_reply_failures
    error = Discordrb::Errors::NoPermission.new('no permission')
    message = FakeMessage.new(content: 'https://twitter.com/a/status/1')
    event = FakeMessageEvent.new(message: message, respond_error: error)

    @handlers.on_message(event)

    assert_empty @sentry.captured
    assert @logger.logged?(:error, 'Failed to reply with fixed link')
  end

  def test_records_the_channel_id
    message = FakeMessage.new(content: 'https://twitter.com/a/status/1')
    event = FakeMessageEvent.new(message:)

    @handlers.on_message(event)

    assert_equal event.channel.id, Message.first(original_message_id: 1000).channel_id
  end

  def test_reply_does_not_allow_pings
    message = FakeMessage.new(content: 'https://twitter.com/a/status/1')
    event = FakeMessageEvent.new(message:)

    @handlers.on_message(event)

    assert_equal({ parse: [], replied_user: false }, event.response_args.last[3])
  end

  def test_resuppresses_embeds_when_an_edited_link_is_updated
    Message.create(original_message_id: 1000, fixed_message_id: 2000)
    message = FakeMessage.new(content: 'now https://pixiv.net/en/artworks/1')
    event = FakeMessageEvent.new(message:)

    @handlers.on_message_edit(event)

    assert_equal 1, message.suppress_calls
  end

  # The suppress PATCH echoes back as a message update carrying the flag and
  # authored by the original author, so re-suppressing it would feed itself
  # forever at the per-channel edit rate limit.
  def test_does_not_suppress_again_when_its_own_echo_comes_back
    message = FakeMessage.new(content: 'see https://twitter.com/a/status/1')
    @handlers.on_message(FakeMessageEvent.new(message:))
    echo = FakeMessage.new(content: message.content)
    echo.flags = FakeMessage::SUPPRESS_EMBEDS
    event = FakeMessageEvent.new(message: echo)

    @handlers.on_message_edit(event)

    assert_equal 1, message.suppress_calls
    assert_equal 0, echo.suppress_calls
    assert_equal [[2000, 'https://vxtwitter.com/a/status/1']], event.channel.edited
  end

  def test_does_not_resuppress_embeds_when_an_edit_removes_the_link
    Message.create(original_message_id: 1000, fixed_message_id: 2000)
    message = FakeMessage.new(content: 'no links')
    event = FakeMessageEvent.new(message:)

    @handlers.on_message_edit(event)

    assert_equal 0, message.suppress_calls
  end

  def test_truncates_replies_at_the_message_limit
    links = (1..20).map { |index| "https://twitter.com/user/status/#{'9' * 100}#{index}" }.join(' ')
    message = FakeMessage.new(content: links)
    event = FakeMessageEvent.new(message:)

    @handlers.on_message(event)

    assert_operator event.responses.first.length, :<=, ReplyContent::MESSAGE_LIMIT
    assert @logger.logged?(:warn, 'Dropped fixed links over the message limit')
    refute_nil Message.first(original_message_id: 1000)
  end

  def test_truncates_a_single_link_longer_than_the_message_limit
    long_link = "https://twitter.com/user/#{'a' * 2500}"
    message = FakeMessage.new(content: long_link)
    event = FakeMessageEvent.new(message:)

    @handlers.on_message(event)

    assert_equal ReplyContent::MESSAGE_LIMIT, event.responses.first.length
    assert @logger.logged?(:warn, 'Truncated fixed link to message limit')
  end

  def test_reposts_when_the_fixed_reply_was_deleted
    Message.create(original_message_id: 1000, fixed_message_id: 2000)
    channel = FakeChannel.new(load_error: Discordrb::Errors::UnknownMessage.new('Unknown Message'))
    message = FakeMessage.new(content: 'https://twitter.com/a/status/1')
    event = FakeMessageEvent.new(message:, channel:)

    @handlers.on_message_edit(event)

    assert_equal ['https://vxtwitter.com/a/status/1'], event.responses
    assert_equal 2000, Message.first(original_message_id: 1000).fixed_message_id
    assert @logger.logged?(:info, 'Fixed link message is gone; posting a new one')
  end

  def test_serializes_concurrent_messages_for_the_same_id
    message = FakeMessage.new(content: 'https://twitter.com/a/status/1')
    event = FakeMessageEvent.new(message:)

    Array.new(5) { Thread.new { @handlers.on_message(event) } }.each(&:join)

    assert_equal 1, event.responses.length
    assert_equal 1, Message.dataset.count
  end

  def test_captures_unexpected_handler_errors
    error = StandardError.new('boom')
    message = exploding_message(error)
    event = FakeMessageEvent.new(message:)

    @handlers.on_message(event)

    assert_equal [error], @sentry.captured
    assert @logger.logged?(:error, 'Handler failed')
  end

  def test_does_not_capture_expected_handler_errors
    error = Discordrb::Errors::NoPermission.new('no permission')
    message = exploding_message(error)
    event = FakeMessageEvent.new(message:)

    @handlers.on_message(event)

    assert_empty @sentry.captured
    assert @logger.logged?(:error, 'Handler failed')
  end

  private

  def old_message(content)
    message = FakeMessage.new(content:)
    message.timestamp = Time.now - (40 * 86_400)
    message
  end

  def exploding_message(error)
    Class.new do
      define_method(:content) { raise error }
      define_method(:author) { Author.new('tester', false) }
      define_method(:id) { 1000 }
    end.new
  end
end
