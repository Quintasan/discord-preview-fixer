# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  enable_coverage :branch
  skip '/test/'
  minimum_coverage 90
end

ENV['DB_PATH'] = ':memory:'

require 'services'
require 'link_fixer'
require 'message_schema'
require 'message'
require 'uri'
