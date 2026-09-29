# frozen_string_literal: true

require_relative 'test_helper'
require 'handlers'

class HandlersTest < Minitest::Test
  Author = Struct.new(:display_name)
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
    attr_reader :content, :author, :id, :suppress_calls

    def initialize(content:, id: 1000, display_name: 'tester', suppress_error: nil)
      @content = content
      @id = id
      @author = Author.new(display_name)
      @suppress_error = suppress_error
      @suppress_calls = 0
    end

    def suppress_embeds
      @suppress_calls += 1
      raise @suppress_error if @suppress_error
    end
  end

  class FakeMessageEvent
    attr_reader :message, :responses

    def initialize(message:, response_id: 2000, respond_error: nil)
      @message = message
      @response_id = response_id
      @respond_error = respond_error
      @responses = []
    end

    def respond(content, *_args)
      raise @respond_error if @respond_error

      @responses << content
      Response.new(@response_id)
    end
  end

  class FakeChannel
    attr_reader :deleted

    def initialize(error: nil)
      @deleted = []
      @error = error
    end

    def delete_message(id)
      raise @error if @error

      @deleted << id
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
    @handlers = Handlers.new(logger: @logger, sentry: @sentry)
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
end
