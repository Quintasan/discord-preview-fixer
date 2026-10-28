# frozen_string_literal: true

require_relative 'service'

class Instagram < Service
  HOST_REGEX = /\A(www\.|m\.)?(instagram\.com|instagr\.am)\z/i
  REPLACEMENT_HOST = 'eeinstagram.com'
end
