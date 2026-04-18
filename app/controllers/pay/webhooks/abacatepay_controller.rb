module Pay
  module Webhooks
    class AbacatepayController < ActionController::API
      def create
        payload = request.body.read
        signature = request.headers["X-Webhook-Signature"]
        return head(:unauthorized) if signature.blank?

        ::AbacatePay::Webhooks.verify!(
          payload: payload,
          signature: signature,
          secret: Pay::Abacatepay.webhook_secret
        )

        event_hash = JSON.parse(payload)
        event_type = event_hash["event"] || event_hash["type"]
        event_id = event_hash["id"] || event_hash.dig("data", "id")

        return head(:ok) if already_recorded?(event_type, event_id)

        queue_event(event_type, event_hash)
        head :ok
      rescue ::AbacatePay::Webhooks::SignatureError
        head :unauthorized
      rescue JSON::ParserError
        head :bad_request
      end

      private

      def already_recorded?(event_type, event_id)
        return false if event_id.blank?

        Pay::Webhook
          .where(processor: "abacatepay", event_type: event_type)
          .find_each
          .any? { |w| w.event.is_a?(Hash) && (w.event["id"] == event_id.to_s || w.event.dig("data", "id") == event_id.to_s) }
      end

      def queue_event(event_type, event_hash)
        unless Pay::Webhooks.delegator.listening?("abacatepay.#{event_type}")
          Rails.logger.debug { "[pay-abacatepay] no listener for abacatepay.#{event_type}; ignoring" }
          return
        end

        record = Pay::Webhook.create!(processor: :abacatepay, event_type: event_type, event: event_hash)
        Pay::Webhooks::ProcessJob.perform_later(record)
      end
    end
  end
end
