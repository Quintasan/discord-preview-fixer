# frozen_string_literal: true

require_relative 'service'

class Instagram < Service
  HOST_REGEX = /\A(www\.)?instagram\.com\z/i
  REPLACEMENT_HOST = 'eeinstagram.com'
end
