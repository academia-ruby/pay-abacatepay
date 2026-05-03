ENV["RAILS_ENV"] ||= "test"
ENV["ABACATEPAY_WEBHOOK_SECRET"] ||= "wsec_test_secret"

require_relative "dummy/config/environment"
require "rails/test_help"
require "minitest/autorun"
require "webmock/minitest"
require_relative "support/webhook_signature_helper"
require_relative "support/vcr_setup"

ActiveRecord::Schema.verbose = false
load File.expand_path("dummy/db/schema.rb", __dir__)

WebMock.disable_net_connect!(allow_localhost: true)

class ActiveSupport::TestCase
  setup do
    ::AbacatePay.reset!
    ::AbacatePay.configure do |c|
      # Em replay, o token literal não importa (VCR responde local). Em gravação,
      # o token real vem de ENV["ABACATEPAY_API_KEY"] e é filtrado pela cassette.
      c.api_token = ENV["ABACATEPAY_API_KEY"].presence || "abc_dev_test_token"
      c.environment = :sandbox
    end
  end
end

class ActionDispatch::IntegrationTest
  include WebhookSignatureHelper
end
