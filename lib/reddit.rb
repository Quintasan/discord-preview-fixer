# frozen_string_literal: true

require_relative 'service'

class Reddit < Service
  HOST_REGEX = /\A(www\.|old\.)?reddit\.com\z/i
  REPLACEMENT_HOST = 'rxddit.com'
end
