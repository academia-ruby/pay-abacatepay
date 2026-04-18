require "test_helper"

module Pay
  module Abacatepay
    module Webhooks
      class SubscriptionTrialStartedTest < ActiveSupport::TestCase
        test "raises NotImplementedError until the event is confirmed by AbacatePay" do
          error = assert_raises(NotImplementedError) { SubscriptionTrialStarted.new.call({}) }
          assert_match(/trial_started/, error.message)
        end
      end
    end
  end
end
