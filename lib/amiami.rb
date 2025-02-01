module AmiAmi
  REGEX = %r{https?://(?<domain>www.amiami.com)(?<rest>/\S*)}i

  def self.fix_link(event)
    message = event.message.to_s
    old_link = message.match(REGEX).to_s
    old_link.gsub('www.amiami.com', 'figurki.harvestasha.org')
  end
end
