# frozen_string_literal: true

class Service
  def self.fix_link(uri)
    return unless uri.host.match?(self::HOST_REGEX)

    rewrite(uri.dup).to_s
  end

  # Subclasses may override to adjust the path or query. The default rewrites
  # the host and leaves the rest of the URL intact.
  def self.rewrite(uri)
    uri.host = self::REPLACEMENT_HOST
    uri
  end
end
