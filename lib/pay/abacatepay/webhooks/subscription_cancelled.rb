module Pay
  module Abacatepay
    module Webhooks
      class SubscriptionCancelled
        def call(event_hash)
          event = Pay::Abacatepay::Webhooks::Event.new(event_hash)
          result = Pay::Abacatepay::ProcessedWebhook.process!(event_type: event.type, event_id: event.id) do
            handle(event)
          end
          log_already_processed(event) if result == :already_processed
        end

        private

        def handle(event)
          subscription = Pay::Abacatepay::Subscription.find_by(processor_id: event.subscription_id)

          if subscription.nil?
            Rails.logger.warn(
              "[pay-abacatepay] subscription.cancelled for unknown subscription #{event.subscription_id}; no-op"
            )
            return
          end

          subscription.update!(status: "canceled", ends_at: event.canceled_at || Time.current)
        end

        def log_already_processed(event)
          Rails.logger.info("[pay-abacatepay] #{event.type} #{event.id} already processed")
        end
      end
    end
  end
end
