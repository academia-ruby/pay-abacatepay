ENV["RAILS_ENV"] ||= "test"

require_relative "dummy/config/environment"
require "rails/test_help"
require "minitest/autorun"
require "webmock/minitest"

ActiveRecord::Schema.verbose = false
load File.expand_path("dummy/db/schema.rb", __dir__)

WebMock.disable_net_connect!(allow_localhost: true)

class ActiveSupport::TestCase
  setup do
    ::AbacatePay.reset!
    ::AbacatePay.configure do |c|
      c.api_token = "abc_dev_test_token"
      c.environment = :sandbox
    end
  end
end
