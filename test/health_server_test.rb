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

  private

  def request
    socket = TCPSocket.new('127.0.0.1', @server.port)
    socket.write("GET /healthz HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
    response = socket.read
    socket.close

    [response[%r{^HTTP/1\.1 (\d+)}, 1], response.split("\r\n\r\n", 2).last]
  end
end
