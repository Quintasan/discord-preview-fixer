# frozen_string_literal: true

require_relative 'service'

class Pixiv < Service
  HOST_REGEX = /\A(www\.)?pixiv\.net\z/i
  REPLACEMENT_HOST = 'phixiv.net'
end
