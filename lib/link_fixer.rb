# frozen_string_literal: true

require 'uri'
require_relative 'service'

class LinkFixer
  HTTP_REGEX = URI::DEFAULT_PARSER.make_regexp(%w[http https])

  TRAILING_PUNCTUATION = /[.,!?;:)\]}>"']+\z/

  SPOILER_REGEX = /\|\|.*\|\|/

  def self.fix(message)
    new(message).fix
  end

  def initialize(message)
    @message = message.to_s
  end

  def fix
    links = extract_uris.filter_map { |uri| fix_uri(uri) }
    return [] if links.empty?

    wrap_in_spoilers(links)
  end

  private

  def extract_uris
    @message.to_enum(:scan, HTTP_REGEX).filter_map do
      raw = Regexp.last_match(0).sub(TRAILING_PUNCTUATION, '')
      next if raw.empty?

      URI.parse(raw)
    rescue URI::InvalidURIError
      nil
    end
  end

  def fix_uri(uri)
    Service.subclasses.lazy.filter_map { |service| service.fix_link(uri) }.first
  end

  def wrap_in_spoilers(links)
    return links unless @message.match?(SPOILER_REGEX)

    links.map { |link| "|| #{link} ||" }
  end
end
