require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

require "pay"
require "pay/abacatepay"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f

    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.active_job.queue_adapter = :test
    config.action_controller.allow_forgery_protection = false
  end
end
