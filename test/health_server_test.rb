# frozen_string_literal: true

require_relative 'test_helper'
require 'health'

class HealthServerTest < Minitest::Test
  class StubBot
    def initialize(connected)
      @connected = connected
    end

    def connected?
      @connected
    end
  end

  class NullLogger
    %i[info error warn debug].each { |level| define_method(level) { |*_args| nil } }
  end

  class RecordingLogger
    attr_reader :errors

    def initialize
      @errors = []
    end

    def error(message, **context)
      @errors << [message, context]
    end

    %i[info warn debug].each { |level| define_method(level) { |*_args, **_kwargs| nil } }
  end

  # Raises a recoverable error on the first accept, then reports the socket as
  # closed so #serve can exit its retry loop.
  class FlakyTCPServer
    def initialize
      @calls = 0
    end

    def accept
      @calls += 1
      raise StandardError, 'boom' if @calls == 1

      raise IOError, 'closed'
    end
  end

  class ClosableServer
    attr_reader :closed

    def close
      @closed = true
    end
  end

  def setup
    @server = HealthServer.start(bot: StubBot.new(true), logger: NullLogger.new, port: 0)
  end

  def teardown
    @server.stop
  end

  def test_returns_200_when_connected
    status, body = request

    assert_equal '200', status
    assert_equal 'ok', body
  end

  def test_returns_503_when_disconnected
    @server.stop
    @server = HealthServer.start(bot: StubBot.new(false), logger: NullLogger.new, port: 0)

    status, body = request

    assert_equal '503', status
    assert_equal 'unhealthy', body
  end

  def test_logs_and_retries_when_accept_fails
    logger = RecordingLogger.new
    server = HealthServer.allocate
    server.instance_variable_set(:@logger, logger)
    server.instance_variable_set(:@tcp_server, FlakyTCPServer.new)
    server.define_singleton_method(:sleep) { |_seconds| nil }

    server.send(:serve)

    assert_equal [['Health server error', { error: 'boom' }]], logger.errors
  end

  def test_stop_without_started_thread
    server = HealthServer.allocate
    tcp_server = ClosableServer.new
    server.instance_variable_set(:@tcp_server, tcp_server)

    server.stop

    assert tcp_server.closed
  end

  private

  def request
    socket = TCPSocket.new('127.0.0.1', @server.port)
    socket.write("GET /healthz HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
    response = socket.read
    socket.close

    [response[%r{^HTTP/1\.1 (\d+)}, 1], response.split("\r\n\r\n", 2).last]
  end
end
