# frozen_string_literal: true

require_relative 'service'

class AmiAmi < Service
  HOST_REGEX = /\A(www\.)?amiami\.com\z/i
  REPLACEMENT_HOST = 'figurki.harvestasha.org'
end
