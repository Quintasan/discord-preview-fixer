# frozen_string_literal: true

class Service
  def self.fix_link(uri)
    return unless uri.host.match?(self::HOST_REGEX)

    uri = uri.dup
    uri.host = self::REPLACEMENT_HOST
    uri.to_s
  end
end
