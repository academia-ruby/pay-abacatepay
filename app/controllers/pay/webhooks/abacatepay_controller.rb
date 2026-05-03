module Pay
  module Webhooks
    class AbacatepayController < ActionController::API
      # Authenticates a webhook delivery per the official AbacatePay scheme
      # (https://docs.abacatepay.com/pages/webhooks/security).
      #
      # AbacatePay combines two complementary mechanisms — neither alone is
      # sufficient, but **either** is enough to mark a delivery as genuine for
      # this gem (we accept the strongest available):
      #
      #   1. **`webhookSecret` query parameter** — AbacatePay appends the
      #      per-webhook secret you configured in the dashboard to the URL:
      #      `?webhookSecret=...`. This authenticates the **origin** because
      #      only AbacatePay knows your secret. Compared against
      #      `Pay::Abacatepay.webhook_secret`.
      #
      #   2. **`X-Webhook-Signature` header (HMAC-SHA256, base64)** — protects
      #      **body integrity**. Computed by AbacatePay over the raw body
      #      using their fixed `PUBLIC_KEY` (in the SDK as a constant). The
      #      key is public, so this alone does NOT prove origin — it only
      #      proves the body wasn't tampered with in transit.
      #
      # Sandbox compatibility: the current AbacatePay sandbox occasionally
      # delivers `webhookSecret` inside the JSON body instead of the URL.
      # We accept that as a third path (compared against the same configured
      # secret) so dev/staging environments work without painel reconfiguration.
      #
      # The request is rejected with 401 if none of the three pass.
      def create
        payload = request.body.read

        unless authenticated?(payload)
          return head(:unauthorized)
        end

        event_hash = JSON.parse(payload)
        event_type = event_hash["event"] || event_hash["type"]
        event_id = event_hash["id"] || event_hash.dig("data", "id")

        return head(:ok) if already_recorded?(event_type, event_id)

        queue_event(event_type, event_hash)
        head :ok
      rescue JSON::ParserError
        head :bad_request
      end

      private

      def authenticated?(payload)
        configured_secret = Pay::Abacatepay.webhook_secret
        return false if configured_secret.blank?

        # 1. Query parameter (official scheme)
        query_secret = request.query_parameters["webhookSecret"]
        if query_secret.present?
          return secrets_match?(query_secret, configured_secret)
        end

        # 2. HMAC-SHA256 base64 in X-Webhook-Signature header.
        # Uses AbacatePay's fixed PUBLIC_KEY (NOT the per-webhook secret).
        if (signature = request.headers["X-Webhook-Signature"]).present?
          return ::AbacatePay::Webhooks.valid?(payload: payload, signature: signature)
        end

        # 3. Sandbox compatibility: webhookSecret inside JSON body
        body_secret = extract_body_secret(payload)
        return false if body_secret.blank?

        secrets_match?(body_secret, configured_secret)
      end

      def secrets_match?(received, expected)
        ActiveSupport::SecurityUtils.secure_compare(received.to_s, expected.to_s)
      end

      def extract_body_secret(payload)
        parsed = JSON.parse(payload)
        parsed["webhookSecret"] || parsed.dig("webhook_secret")
      rescue JSON::ParserError
        nil
      end

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
