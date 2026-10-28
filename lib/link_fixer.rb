# frozen_string_literal: true

require 'uri'
require_relative 'service'

class LinkFixer
  HTTP_REGEX = URI::RFC2396_PARSER.make_regexp(%w[http https])

  TRAILING_PUNCTUATION = /[.,!?;:)\]}>"']+\z/

  def self.fix(message)
    new(message).fix
  end

  def initialize(message)
    @message = message.to_s
  end

  def fix
    links = extract_links.filter_map do |uri, spoiler|
      fixed = fix_uri(uri)
      [fixed, spoiler] if fixed
    end
    return [] if links.empty?

    deduplicate(links).map { |url, spoiler| spoiler ? "|| #{url} ||" : url }
  end

  private

  def extract_links
    @message.to_enum(:scan, HTTP_REGEX).filter_map do
      match = Regexp.last_match
      start = match.begin(0)
      next if inside_code?(start)

      [URI.parse(match[0].sub(TRAILING_PUNCTUATION, '')), inside_spoiler?(start)]
    rescue URI::InvalidURIError
      nil
    end
  end

  def fix_uri(uri)
    Service.subclasses.lazy.filter_map { |service| service.fix_link(uri) }.first
  end

  # A fixed link is spoilered if any occurrence of it was spoilered, so a
  # spoilered link is never leaked by a duplicate outside a spoiler.
  def deduplicate(links)
    links.group_by(&:first).map do |url, occurrences|
      [url, occurrences.any? { |_, spoiler| spoiler }]
    end
  end

  def inside_spoiler?(offset)
    @spoiler_spans ||= spans('||')
    @spoiler_spans.any? { |span| span.cover?(offset) }
  end

  def inside_code?(offset)
    @code_spans ||= code_spans
    @code_spans.any? { |span| span.cover?(offset) }
  end

  # Pairs delimiters left to right. An unmatched delimiter starts no span and
  # is skipped, so a later pair is still recognized.
  def spans(delimiter)
    ranges = []
    position = 0
    while (open = @message.index(delimiter, position))
      position = append_span(ranges, open, delimiter)
    end
    ranges
  end

  # Code spans pair runs of backticks, so inline code, multi-backtick code, and
  # fenced blocks all work. A run without a matching close starts no span.
  def code_spans
    ranges = []
    position = 0
    while (run = @message.match(/`+/, position))
      position = append_span(ranges, run.begin(0), run[0])
    end
    ranges
  end

  def append_span(ranges, open, delimiter)
    close = @message.index(delimiter, open + delimiter.length)
    return open + delimiter.length unless close

    ranges << (open...(close + delimiter.length))
    close + delimiter.length
  end
end
