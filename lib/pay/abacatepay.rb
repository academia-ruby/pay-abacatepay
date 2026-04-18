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
    autoload :Webhooks, "pay/abacatepay/webhooks"

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

    # Registers handlers for every AbacatePay webhook event with Pay::Webhooks.
    # Invoked by the engine's `before_initialize` hook so handlers are in place
    # before host-app initializers run.
    def self.configure_webhooks
      Pay::Webhooks.configure do |events|
        events.subscribe "abacatepay.checkout.completed", Pay::Abacatepay::Webhooks::CheckoutCompleted.new
        events.subscribe "abacatepay.checkout.refunded", Pay::Abacatepay::Webhooks::CheckoutRefunded.new
        events.subscribe "abacatepay.checkout.disputed", Pay::Abacatepay::Webhooks::CheckoutDisputed.new
        events.subscribe "abacatepay.checkout.lost", Pay::Abacatepay::Webhooks::CheckoutLost.new
        events.subscribe "abacatepay.transparent.completed", Pay::Abacatepay::Webhooks::TransparentCompleted.new
        events.subscribe "abacatepay.transparent.refunded", Pay::Abacatepay::Webhooks::TransparentRefunded.new
        events.subscribe "abacatepay.transparent.disputed", Pay::Abacatepay::Webhooks::TransparentDisputed.new
        events.subscribe "abacatepay.transparent.lost", Pay::Abacatepay::Webhooks::TransparentLost.new
        events.subscribe "abacatepay.subscription.completed", Pay::Abacatepay::Webhooks::SubscriptionCompleted.new
        events.subscribe "abacatepay.subscription.cancelled", Pay::Abacatepay::Webhooks::SubscriptionCancelled.new
        events.subscribe "abacatepay.subscription.renewed", Pay::Abacatepay::Webhooks::SubscriptionRenewed.new
        events.subscribe "abacatepay.subscription.trial_started", Pay::Abacatepay::Webhooks::SubscriptionTrialStarted.new
        events.subscribe "abacatepay.payout.completed", Pay::Abacatepay::Webhooks::PayoutCompleted.new
        events.subscribe "abacatepay.payout.failed", Pay::Abacatepay::Webhooks::PayoutFailed.new
        events.subscribe "abacatepay.transfer.completed", Pay::Abacatepay::Webhooks::TransferCompleted.new
        events.subscribe "abacatepay.transfer.failed", Pay::Abacatepay::Webhooks::TransferFailed.new
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
