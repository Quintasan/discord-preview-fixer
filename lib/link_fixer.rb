# frozen_string_literal: true

require 'uri'
require_relative 'service'

class LinkFixer
  HTTP_REGEX = URI::RFC2396_PARSER.make_regexp(%w[http https])

  TRAILING_PUNCTUATION = /[.,!?;:)\]}>"']+\z/

  SPOILER = '||'

  def self.fix(message)
    new(message).fix
  end

  def initialize(message)
    @message = message.to_s
  end

  def fix
    # @type var links: Array[[String, bool]]
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
      # @type var match: MatchData
      match = Regexp.last_match
      # @type var start: Integer
      start = match.begin(0)
      next if inside_code?(start)

      [URI.parse(match[0].sub(TRAILING_PUNCTUATION, '')), inside_spoiler?(start)]
    rescue URI::InvalidURIError
      nil
    end
  end

  def fix_uri(uri)
    # @type var services: Array[singleton(Service)]
    services = Service.subclasses
    services.lazy.filter_map { |service| service.fix_link(uri) }.first
  end

  # A fixed link is spoilered if any occurrence of it was spoilered, so a
  # spoilered link is never leaked by a duplicate outside a spoiler.
  def deduplicate(links)
    links.group_by(&:first).map do |url, occurrences|
      [url, occurrences.any? { |_, spoiler| spoiler }]
    end
  end

  def inside_spoiler?(offset)
    @spoiler_spans ||= spoiler_spans
    @spoiler_spans.any? { |span| span.cover?(offset) }
  end

  def inside_code?(offset)
    @code_spans ||= code_spans
    @code_spans.any? { |span| span.cover?(offset) }
  end

  # Spoiler markers pair left to right, but a marker inside a code span is
  # literal text: `||` in inline code hides nothing. An unmatched marker starts
  # no span and is skipped, so a later pair is still recognized.
  def spoiler_spans
    # @type var ranges: Array[Range[Integer]]
    ranges = []
    position = 0
    while (open = spoiler_marker(position))
      # @type var close: Integer?
      close = spoiler_marker(open + SPOILER.length)
      position = close ? close + SPOILER.length : open + SPOILER.length
      ranges << (open...position) if close
    end
    ranges
  end

  def spoiler_marker(from)
    position = from
    while (found = @message.index(SPOILER, position))
      return found unless inside_code?(found)

      position = found + SPOILER.length
    end
    nil
  end

  # Code spans pair runs of backticks, so inline code, multi-backtick code, and
  # fenced blocks all work. A run without a matching close starts no span.
  def code_spans
    # @type var ranges: Array[Range[Integer]]
    ranges = []
    position = 0
    # @type var run: MatchData
    while (run = @message.match(/`+/, position))
      # @type var open: Integer
      open = run.begin(0)
      position = append_span(ranges, open, run[0])
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
