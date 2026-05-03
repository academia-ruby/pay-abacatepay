module Pay
  module Abacatepay
    class Charge < Pay::Charge
      # AbacatePay checkout status → Pay::Charge status (stored in data).
      # PENDING is created eagerly by Customer#charge so the app can render
      # "payment in progress" UI before the webhook arrives.
      # EXPIRED and CANCELLED never become a Pay::Charge — the payment never
      # succeeded and there is nothing to track.
      STATUS_MAP = {
        "PENDING" => "pending",
        "PAID" => "paid",
        "REFUNDED" => "refunded",
        "DISPUTED" => "disputed"
      }.freeze

      store_accessor :data, :status
      store_accessor :data, :checkout_url
      store_accessor :data, :payment_method

      def self.sync(charge_id, object: nil)
        object ||= ::AbacatePay.checkouts.get(charge_id)

        customer_id = extract_customer_id(object)
        if customer_id.blank?
          Rails.logger.debug("[pay-abacatepay] checkout #{charge_id} has no customer; skipping sync")
          return
        end

        pay_customer = Pay::Customer.find_by(processor: "abacatepay", processor_id: customer_id)
        if pay_customer.nil?
          Rails.logger.debug("[pay-abacatepay] Pay::Customer #{customer_id} not found while syncing checkout #{charge_id}")
          return
        end

        charge = Pay::Abacatepay::Charge.find_or_initialize_by(
          customer: pay_customer,
          processor_id: charge_id
        )
        charge.amount = object.amount if object.respond_to?(:amount) && object.amount
        charge.currency ||= "BRL"
        charge.status = STATUS_MAP[object.status] || charge.status || "pending" if object.respond_to?(:status)
        charge.checkout_url = object.url if object.respond_to?(:url) && object.url
        charge.save!
        charge
      rescue ::AbacatePay::Error => e
        raise Pay::Abacatepay::Error, e.message
      end

      def api_record
        ::AbacatePay.checkouts.get(processor_id)
      rescue ::AbacatePay::Error => e
        raise Pay::Abacatepay::Error, e.message
      end

      def refund!(_amount_to_refund = nil)
        raise Pay::Abacatepay::Error,
          "AbacatePay does not expose a refund endpoint. " \
          "Process the refund in the AbacatePay dashboard; the checkout.refunded " \
          "webhook will update this Pay::Charge automatically."
      end

      def charged_back?
        status == "disputed"
      end

      def self.extract_customer_id(object)
        return object.dig("customer", "id") if object.is_a?(Hash)
        customer = object.respond_to?(:customer) ? object.customer : nil
        return nil if customer.nil?
        customer.respond_to?(:id) ? customer.id : customer["id"]
      end
      private_class_method :extract_customer_id
    end
  end
end

ActiveSupport.run_load_hooks :pay_abacatepay_charge, Pay::Abacatepay::Charge
