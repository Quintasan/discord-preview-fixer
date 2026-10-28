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

  def test_subclasses_can_override_rewrite
    assert_equal 'https://override.example/path',
                 override_service.fix_link(URI.parse('https://override.invalid/path?tracking=1'))
  end

  private

  def override_service
    Class.new(Service) do
      const_set(:HOST_REGEX, /\Aoverride\.invalid\z/)
      const_set(:REPLACEMENT_HOST, 'override.example')

      def self.rewrite(uri)
        rewritten = super
        rewritten.query = nil
        rewritten
      end
    end
  end
end
