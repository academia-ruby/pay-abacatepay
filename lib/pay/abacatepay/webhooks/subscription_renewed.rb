module Pay
  module Abacatepay
    module Webhooks
      class SubscriptionRenewed
        def call(event_hash)
          event = Pay::Abacatepay::Webhooks::Event.new(event_hash)
          result = Pay::Abacatepay::ProcessedWebhook.process!(event_type: event.type, event_id: event.id) do
            handle(event)
          end
          log_already_processed(event) if result == :already_processed
        end

        private

        def handle(event)
          existing = Pay::Abacatepay::Subscription.find_by(processor_id: event.subscription_id)

          if existing.nil?
            Rails.logger.warn(
              "[pay-abacatepay] subscription.renewed before subscription.completed for #{event.subscription_id}; " \
              "creating subscription on-the-fly"
            )
          end

          subscription = Pay::Abacatepay::Subscription.sync(event.subscription_id, event: event)
          return if subscription.nil?
          return if event.charge_id.blank?

          Pay::Abacatepay::Charge.find_or_create_by!(customer: subscription.customer, processor_id: event.charge_id) do |charge|
            charge.amount = event.paid_amount_cents || event.charge_amount_cents
            charge.currency = event.subscription_currency
            charge.application_fee_amount = event.platform_fee_cents
            charge.subscription_id = subscription.id
            charge.status = "paid"
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
