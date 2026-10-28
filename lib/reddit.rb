# frozen_string_literal: true

require_relative 'service'

class Reddit < Service
  HOST_REGEX = /\A(www\.|old\.|new\.|np\.|i\.)?reddit\.com\z/i
  REPLACEMENT_HOST = 'rxddit.com'
end
