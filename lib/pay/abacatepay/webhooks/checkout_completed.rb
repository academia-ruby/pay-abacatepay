module Pay
  module Abacatepay
    module Webhooks
      class CheckoutCompleted
        def call(event_hash)
          event = Pay::Abacatepay::Webhooks::Event.new(event_hash)
          result = Pay::Abacatepay::ProcessedWebhook.process!(event_type: event.type, event_id: event.id) do
            handle(event)
          end
          log_already_processed(event) if result == :already_processed
        end

        private

        def handle(event)
          if event.checkout_frequency && event.checkout_frequency != "ONE_TIME"
            Rails.logger.debug(
              "[pay-abacatepay] checkout.completed for #{event.checkout_id} is a subscription payment " \
              "(frequency=#{event.checkout_frequency}); skipping — subscription.renewed handles it"
            )
            return
          end

          customer = Pay::Customer.find_by(processor: "abacatepay", processor_id: event.customer_id)
          if customer.nil?
            Rails.logger.warn(
              "[pay-abacatepay] checkout.completed for unknown customer #{event.customer_id}; " \
              "Pay::Customer must be created via the app signup flow before the webhook arrives"
            )
            return
          end

          charge = Pay::Abacatepay::Charge.find_or_initialize_by(
            customer: customer,
            processor_id: event.checkout_id
          )
          charge.amount = event.checkout_paid_amount_cents || event.checkout_amount_cents
          charge.currency ||= "BRL"
          charge.application_fee_amount = event.checkout_platform_fee_cents
          charge.status = "paid"
          charge.checkout_url = event.checkout_url if event.checkout_url
          charge.created_at = event.paid_at if charge.new_record? && event.paid_at
          charge.save!
        end

        def log_already_processed(event)
          Rails.logger.info("[pay-abacatepay] #{event.type} #{event.id} already processed")
        end
      end
    end
  end
end
