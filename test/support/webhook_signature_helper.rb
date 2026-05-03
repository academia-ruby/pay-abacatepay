require "openssl"
require "base64"

module WebhookSignatureHelper
  # Builds headers an AbacatePay webhook would send, including a valid HMAC.
  # Per https://docs.abacatepay.com/pages/webhooks/security the signature
  # is HMAC-SHA256 over the raw body, base64-encoded, using AbacatePay's
  # fixed `PUBLIC_KEY` (NOT the per-webhook secret).
  #
  # @param payload [String] the raw JSON body to be POSTed
  # @param secret  [String] HMAC key (defaults to AbacatePay's PUBLIC_KEY)
  # @return [Hash{String => String}]
  def abacatepay_webhook_headers(payload, secret: ::AbacatePay::Webhooks::PUBLIC_KEY)
    {
      "Content-Type" => "application/json",
      "X-Webhook-Signature" => Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", secret, payload))
    }
  end
end
