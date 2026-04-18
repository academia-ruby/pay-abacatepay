require "pay"
require "pay/env"
require "abacate_pay"

require "pay/abacatepay/version"
require "pay/abacatepay/engine"

module Pay
  module Abacatepay
    class Error < Pay::Error
    end

    extend Pay::Env

    autoload :Customer, "pay/abacatepay/customer"

    # Enabled when the processor is registered and the SDK constant is present.
    def self.enabled?
      Pay.enabled_processors.include?(:abacatepay) && defined?(::AbacatePay)
    end

    # Configures the upstream SDK with credentials resolved from Rails credentials
    # or environment variables. Called by the engine's `to_prepare` hook.
    def self.setup
      ::AbacatePay.configure do |config|
        config.api_token = api_key
        config.environment = environment
      end
    end

    def self.api_key
      find_value_by_name(:abacatepay, :api_key)
    end

    def self.webhook_secret
      find_value_by_name(:abacatepay, :webhook_secret)
    end

    # The SDK validates this against %i[sandbox production]. The actual API
    # version (v1/v2) is chosen by the SDK based on the token prefix
    # (`abc_dev_*` / `abc_live_*` → v2). Defaults to :sandbox for safety.
    def self.environment
      (find_value_by_name(:abacatepay, :environment) || "sandbox").to_sym
    end
  end
end
