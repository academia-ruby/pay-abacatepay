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

      CheckoutResult = Struct.new(:id, :url, :charge, keyword_init: true)

      def charge(amount, product_id: nil, methods: ["PIX", "CARD"], return_url: nil, completion_url: nil, external_id: nil, product_name: "Cobrança avulsa")
        api_record unless processor_id?

        product_id ||= create_one_time_product(amount, product_name)
        resource = build_checkout_resource(
          product_id: product_id,
          quantity: 1,
          methods: methods,
          return_url: return_url,
          completion_url: completion_url,
          external_id: external_id
        )
        created = ::AbacatePay.checkouts.create(resource)

        pay_charge = Pay::Abacatepay::Charge.find_or_initialize_by(
          customer: self,
          processor_id: created.id
        )
        pay_charge.amount = amount
        pay_charge.currency ||= "BRL"
        pay_charge.status = "pending"
        pay_charge.checkout_url = created.url
        pay_charge.save!

        CheckoutResult.new(id: created.id, url: created.url, charge: pay_charge)
      rescue ::AbacatePay::Error => e
        raise Pay::Abacatepay::Error, e.message
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        raise NotImplementedError, "Pay::Abacatepay::Customer#subscribe is planned for a future release"
      end

      def add_payment_method(payment_method_id, default: false)
        raise NotImplementedError, "Pay::Abacatepay::Customer#add_payment_method is planned for a future release"
      end

      private

      def create_one_time_product(amount, product_name)
        resource = ::AbacatePay::Resources::Products.new(
          external_id: "pay-abacatepay-#{SecureRandom.hex(8)}",
          name: product_name,
          price: amount,
          currency: "BRL"
        )
        created = ::AbacatePay.products.create(resource)
        created.id
      end

      def build_checkout_resource(product_id:, quantity:, methods:, return_url:, completion_url:, external_id:)
        ::AbacatePay::Resources::Checkouts.new(
          frequency: "ONE_TIME",
          methods: methods,
          metadata: {returnUrl: return_url, completionUrl: completion_url}.compact,
          products: [{externalId: product_id, quantity: quantity}],
          customer: {id: processor_id},
          externalId: external_id
        )
      end

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
