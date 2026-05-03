module Pay
  module Abacatepay
    # Stub STI class for Pay::PaymentMethod scoped to AbacatePay.
    #
    # AbacatePay does not (yet) expose tokenized payment methods that we can
    # store and reuse — every transparent transaction needs full card data.
    # This class exists so that:
    #
    #   1. `Pay::Abacatepay::Customer has_many :payment_methods` resolves
    #      correctly (avoids `Missing model class` error on customer destroy).
    #   2. We can persist tokenized payment methods later without breaking
    #      existing data when transparent checkout lands (Fase 5).
    #
    # Until transparent checkout is implemented, instances of this class
    # are not created — the relation is empty for every customer.
    class PaymentMethod < Pay::PaymentMethod
    end
  end
end

ActiveSupport.run_load_hooks :pay_abacatepay_payment_method, Pay::Abacatepay::PaymentMethod
