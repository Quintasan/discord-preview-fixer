# frozen_string_literal: true

require_relative 'service'

class Tiktok < Service
  HOST_REGEX = /\A(www\.|vm\.|vt\.|m\.)?tiktok\.com\z/i
  REPLACEMENT_HOST = 'tnktok.com'
end
