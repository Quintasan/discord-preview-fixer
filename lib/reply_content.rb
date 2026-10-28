# frozen_string_literal: true

# Fits fixed links into one Discord message: links that do not fit are dropped,
# and a single oversized link is truncated so the reply is never empty.
class ReplyContent
  MESSAGE_LIMIT = 2000

  def self.build(fixed_links, message_id:, logger:)
    new(fixed_links, message_id:, logger:).build
  end

  def initialize(fixed_links, message_id:, logger:)
    @fixed_links = fixed_links
    @message_id = message_id
    @logger = logger
  end

  def build
    accepted = []
    dropped = 0
    @fixed_links.each do |link|
      dropped += 1 if add(accepted, link) == :dropped
    end
    log_dropped(dropped)
    accepted.join("\n")
  end

  private

  def add(accepted, link)
    if fits?(accepted, link)
      accepted << link
      return :added
    end
    return truncate(accepted, link) if accepted.empty?

    :dropped
  end

  def fits?(accepted, link)
    (accepted + [link]).join("\n").length <= MESSAGE_LIMIT
  end

  def truncate(accepted, link)
    accepted << link[0, MESSAGE_LIMIT]
    @logger.warn('Truncated fixed link to message limit', message_id: @message_id)
    :added
  end

  def log_dropped(dropped)
    return unless dropped.positive?

    @logger.warn('Dropped fixed links over the message limit', message_id: @message_id, dropped: dropped)
  end
end
