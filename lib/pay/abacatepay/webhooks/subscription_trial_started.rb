module Pay
  module Abacatepay
    module Webhooks
      class SubscriptionTrialStarted
        def call(_event_hash)
          raise NotImplementedError,
            "subscription.trial_started is not listed in AbacatePay::Enums::Webhooks::EventTypes. " \
            "Confirm the event exists in the AbacatePay API before enabling trial support."
        end
      end
    end
  end
end
