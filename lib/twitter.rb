# frozen_string_literal: true

require_relative 'service'

class Twitter < Service
  HOST_REGEX = /\A(www\.)?(twitter\.com|x\.com)\z/i
  REPLACEMENT_HOST = 'vxtwitter.com'
end
