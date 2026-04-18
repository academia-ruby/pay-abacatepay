require "openssl"

module WebhookSignatureHelper
  # Builds headers an AbacatePay webhook would send, including a valid HMAC.
  #
  # @param payload [String] the raw JSON body to be POSTed
  # @param secret  [String] the webhook secret (defaults to the one configured for tests)
  # @return [Hash{String => String}]
  def abacatepay_webhook_headers(payload, secret: Pay::Abacatepay.webhook_secret)
    {
      "Content-Type" => "application/json",
      "X-Webhook-Signature" => OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
    }
  end
end
