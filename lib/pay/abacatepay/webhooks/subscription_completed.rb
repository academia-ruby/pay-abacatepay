module Pay
  module Abacatepay
    module Webhooks
      class SubscriptionCompleted
        def call(event_hash)
          event = Pay::Abacatepay::Webhooks::Event.new(event_hash)
          result = Pay::Abacatepay::ProcessedWebhook.process!(event_type: event.type, event_id: event.id) do
            handle(event)
          end
          log_already_processed(event) if result == :already_processed
        end

        private

        def handle(event)
          customer = find_customer(event)
          return if customer.nil?

          subscription = Pay::Abacatepay::Subscription.sync(event.subscription_id, event: event)
          create_initial_charge(customer, subscription, event) if subscription && event.charge_id
        end

        def find_customer(event)
          return nil if event.customer_id.blank?

          customer = Pay::Customer.find_by(processor: "abacatepay", processor_id: event.customer_id)
          if customer.nil?
            Rails.logger.warn(
              "[pay-abacatepay] subscription.completed for unknown customer #{event.customer_id}; " \
              "Pay::Customer must be created via the app signup flow before the webhook arrives"
            )
          end
          customer
        end

        def create_initial_charge(customer, subscription, event)
          customer.charges.find_or_create_by!(processor_id: event.charge_id) do |charge|
            charge.amount = event.paid_amount_cents || event.charge_amount_cents
            charge.currency = event.subscription_currency
            charge.application_fee_amount = event.platform_fee_cents
            charge.subscription_id = subscription.id
            charge.created_at = event.paid_at if event.paid_at
          end
        end

        def log_already_processed(event)
          Rails.logger.info("[pay-abacatepay] #{event.type} #{event.id} already processed")
        end
      end
    end
  end
end
