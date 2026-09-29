# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  enable_coverage :branch
  skip '/test/'
  minimum_coverage 90
end

ENV['DB_PATH'] = ':memory:'

require 'amiami'
require 'pixiv'
require 'reddit'
require 'twitter'
require 'instagram'
require 'tiktok'
require 'link_fixer'
require 'message'
require 'uri'
