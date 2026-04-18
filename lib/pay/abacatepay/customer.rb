module Pay
  module Abacatepay
    class Customer < Pay::Customer
      has_many :charges, dependent: :destroy, class_name: "Pay::Abacatepay::Charge"
      has_many :subscriptions, dependent: :destroy, class_name: "Pay::Abacatepay::Subscription"
      has_many :payment_methods, dependent: :destroy, class_name: "Pay::Abacatepay::PaymentMethod"
      has_one :default_payment_method, -> { where(default: true) }, class_name: "Pay::Abacatepay::PaymentMethod"

      def api_record_attributes
        {
          name: customer_name,
          email: email,
          cellphone: owner.try(:cellphone) || owner.try(:phone),
          tax_id: extract_document
        }
      end

      def api_record
        with_lock do
          if processor_id?
            ::AbacatePay.customers.get(processor_id)
          else
            attrs = api_record_attributes
            resource = build_customer_resource(attrs)
            created = ::AbacatePay.customers.create(resource)
            update!(processor_id: created.id)
            created
          end
        end
      rescue ::AbacatePay::Error => e
        raise Pay::Abacatepay::Error, e.message
      end

      # AbacatePay's API does not expose an update endpoint for customers
      # (POST /v2/customers/create and DELETE are the only mutations).
      # TODO: Remove this no-op once the API adds PATCH/PUT support.
      def update_api_record(**attributes)
        logger = defined?(Rails) ? Rails.logger : nil
        logger&.warn(
          "[pay-abacatepay] AbacatePay does not support customer updates; update_api_record is a no-op."
        )
        nil
      end

      def charge(amount, options = {})
        raise NotImplementedError, "Pay::Abacatepay::Customer#charge is planned for a future release"
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        raise NotImplementedError, "Pay::Abacatepay::Customer#subscribe is planned for a future release"
      end

      def add_payment_method(payment_method_id, default: false)
        raise NotImplementedError, "Pay::Abacatepay::Customer#add_payment_method is planned for a future release"
      end

      private

      def build_customer_resource(attrs)
        ::AbacatePay::Resources::Customers.new(
          metadata: ::AbacatePay::Resources::Customers::Metadata.new(
            name: attrs[:name],
            email: attrs[:email],
            cellphone: attrs[:cellphone],
            tax_id: attrs[:tax_id]
          )
        )
      end

      def extract_document
        raw = %i[document cpf cnpj].filter_map { |m| owner.send(m) if owner.respond_to?(m) }.find(&:present?)

        unless %i[document cpf cnpj].any? { |m| owner.respond_to?(m) }
          raise Pay::Abacatepay::Error,
            "#{owner.class} must respond to :document, :cpf, or :cnpj for AbacatePay"
        end

        raise Pay::Abacatepay::Error, "document is required for AbacatePay customers" if raw.blank?

        raw.to_s.gsub(/\D/, "")
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_abacatepay_customer, Pay::Abacatepay::Customer
