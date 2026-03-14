# frozen_string_literal: true

require_relative 'test_helper'

class ServiceTest < Minitest::Test
  def test_fix_link_does_not_mutate_original_uri
    uri = URI.parse('https://twitter.com/user/status/123')
    original_host = uri.host.dup

    Service.subclasses.lazy.filter_map { |k| k.fix_link(uri) }.first

    assert_equal original_host, uri.host
  end

  def test_fix_link_returns_nil_for_unsupported_uri
    uri = URI.parse('https://example.com/page')

    result = Service.subclasses.lazy.filter_map { |k| k.fix_link(uri) }.first

    assert_nil result
  end
end
