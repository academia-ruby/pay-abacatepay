module Pay
  module Abacatepay
    module Webhooks
      class CheckoutRefunded
        def call(event_hash)
          event = Pay::Abacatepay::Webhooks::Event.new(event_hash)
          result = Pay::Abacatepay::ProcessedWebhook.process!(event_type: event.type, event_id: event.id) do
            handle(event)
          end
          log_already_processed(event) if result == :already_processed
        end

        private

        def handle(event)
          charge = Pay::Abacatepay::Charge.find_by(processor_id: event.checkout_id)
          if charge.nil?
            Rails.logger.warn(
              "[pay-abacatepay] checkout.refunded for unknown checkout #{event.checkout_id}; " \
              "no Pay::Abacatepay::Charge to update"
            )
            return
          end

          refund_amount = event.checkout_paid_amount_cents || charge.amount
          charge.update!(
            amount_refunded: refund_amount,
            status: "refunded"
          )
        end

        def log_already_processed(event)
          Rails.logger.info("[pay-abacatepay] #{event.type} #{event.id} already processed")
        end
      end
    end
  end
end
