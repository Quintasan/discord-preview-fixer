# frozen_string_literal: true

require 'sentry-ruby'

Sentry.init do |c|
  c.breadcrumbs_logger = %i[sentry_logger http_logger]
end
