module Pay
  module Abacatepay
    module Webhooks
      autoload :CheckoutCompleted, "pay/abacatepay/webhooks/checkout_completed"
      autoload :CheckoutRefunded, "pay/abacatepay/webhooks/checkout_refunded"
      autoload :CheckoutDisputed, "pay/abacatepay/webhooks/checkout_disputed"
      autoload :CheckoutLost, "pay/abacatepay/webhooks/checkout_lost"
      autoload :TransparentCompleted, "pay/abacatepay/webhooks/transparent_completed"
      autoload :TransparentRefunded, "pay/abacatepay/webhooks/transparent_refunded"
      autoload :TransparentDisputed, "pay/abacatepay/webhooks/transparent_disputed"
      autoload :TransparentLost, "pay/abacatepay/webhooks/transparent_lost"
      autoload :SubscriptionCompleted, "pay/abacatepay/webhooks/subscription_completed"
      autoload :SubscriptionCancelled, "pay/abacatepay/webhooks/subscription_cancelled"
      autoload :SubscriptionRenewed, "pay/abacatepay/webhooks/subscription_renewed"
      autoload :SubscriptionTrialStarted, "pay/abacatepay/webhooks/subscription_trial_started"
      autoload :PayoutCompleted, "pay/abacatepay/webhooks/payout_completed"
      autoload :PayoutFailed, "pay/abacatepay/webhooks/payout_failed"
      autoload :TransferCompleted, "pay/abacatepay/webhooks/transfer_completed"
      autoload :TransferFailed, "pay/abacatepay/webhooks/transfer_failed"
    end
  end
end
