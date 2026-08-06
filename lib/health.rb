# frozen_string_literal: true

require 'socket'

# Minimal HTTP server used for container health checks. Listens on loopback and
# reports whether the bot is currently connected to Discord, so Docker can tell
# if the process is alive *and* actually working.
class HealthServer
  DEFAULT_PORT = 8080

  def self.start(bot:, logger:, port: ENV.fetch('HEALTHCHECK_PORT', DEFAULT_PORT))
    new(bot:, logger:, port:).start
  end

  def initialize(bot:, logger:, port:)
    @bot = bot
    @logger = logger
    @port = Integer(port)
  end

  def start
    @tcp_server = TCPServer.new('127.0.0.1', @port)
    @port = @tcp_server.addr[1] # actual bound port (differs when port 0 is requested)
    @thread = Thread.new { serve }
    @logger.info('Health server started', port: @port)
    self
  end

  attr_reader :port

  def stop
    @tcp_server.close
    @thread&.join(1)
  end

  private

  def serve
    loop do
      handle(@tcp_server.accept)
    end
  rescue IOError, Errno::EBADF, Errno::EINVAL
    nil # server socket closed via #stop
  rescue StandardError => e
    @logger.error('Health server error', error: e.message)
    sleep 1
    retry
  end

  def handle(client)
    client.gets # consume the request line
    client.write(response_for(@bot.connected?))
  ensure
    client.close
  end

  def response_for(healthy)
    status = healthy ? 200 : 503
    reason = healthy ? 'OK' : 'Service Unavailable'
    body = healthy ? 'ok' : 'unhealthy'

    "HTTP/1.1 #{status} #{reason}\r\n" \
      "Content-Type: text/plain\r\n" \
      "Content-Length: #{body.bytesize}\r\n" \
      "Connection: close\r\n\r\n#{body}"
  end
end
