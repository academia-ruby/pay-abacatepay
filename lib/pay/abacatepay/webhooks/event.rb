module Pay
  module Abacatepay
    module Webhooks
      class Event
        def initialize(raw)
          @raw = raw.is_a?(Hash) ? raw : {}
        end

        attr_reader :raw

        def id = @raw["id"]

        def type = @raw["event"] || @raw["type"]

        def data = @raw["data"] || {}

        def api_version = @raw["apiVersion"]

        def dev_mode? = @raw["devMode"] == true

        def subscription_id = data.dig("subscription", "id")

        def subscription_status = data.dig("subscription", "status")

        def subscription_amount_cents = data.dig("subscription", "amount")

        def subscription_currency = data.dig("subscription", "currency") || "BRL"

        def frequency = data.dig("subscription", "frequency")

        def subscription_created_at = parse_time(data.dig("subscription", "createdAt"))

        def subscription_updated_at = parse_time(data.dig("subscription", "updatedAt"))

        def canceled_at = parse_time(data.dig("subscription", "canceledAt"))

        def customer_id = data.dig("customer", "id")

        def customer_email = data.dig("customer", "email")

        def customer_name = data.dig("customer", "name")

        def customer_tax_id = data.dig("customer", "taxId")

        def charge_id = data.dig("payment", "id")

        def charge_amount_cents = data.dig("payment", "amount")

        def paid_amount_cents = data.dig("payment", "paidAmount")

        def platform_fee_cents = data.dig("payment", "platformFee")

        def charge_status = data.dig("payment", "status")

        def paid_at = parse_time(data.dig("payment", "updatedAt"))

        def checkout_id = data.dig("checkout", "id")

        def checkout_frequency = data.dig("checkout", "frequency")

        def checkout_status = data.dig("checkout", "status")

        def checkout_url = data.dig("checkout", "url")

        def checkout_amount_cents = data.dig("checkout", "amount")

        def checkout_paid_amount_cents = data.dig("checkout", "paidAmount")

        def checkout_platform_fee_cents = data.dig("checkout", "platformFee")

        def checkout_methods = data.dig("checkout", "methods")

        def product_id = data.dig("checkout", "items", 0, "id")

        def interval
          Pay::Abacatepay::Frequency.to_interval(frequency)
        end

        private

        def parse_time(value)
          return nil if value.nil? || value.to_s.empty?
          Time.zone ? Time.zone.parse(value.to_s) : Time.parse(value.to_s)
        end
      end
    end
  end
end
