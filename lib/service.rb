# frozen_string_literal: true

class Service
  def self.fix_link(uri)
    # Only absolute http(s) links reach a service, so a host is always present.
    # @type var host: String
    host = uri.host
    return unless host.match?(self::HOST_REGEX)

    rewrite(uri.dup).to_s
  end

  # Subclasses may override to adjust the path or query. The default rewrites
  # the host and leaves the rest of the URL intact. The port goes with the host:
  # it names a server of the old host, so the fixed link uses the scheme default.
  def self.rewrite(uri)
    uri.host = self::REPLACEMENT_HOST
    uri.port = nil
    uri
  end
end
