require "test_helper"

module Pay
  module Abacatepay
    module Webhooks
      class SubscriptionCancelledTest < ActiveSupport::TestCase
        def fixture
          JSON.parse(File.read(File.expand_path("../../../fixtures/webhooks/subscription_cancelled.json", __dir__)))
        end

        setup do
          user = User.create!(email: "m@x.com", name: "Maria", document: "111.222.333-44")
          pay_customer = Pay::Customer.create!(owner: user, processor: "abacatepay", processor_id: "cust_def456")
          @subscription = Pay::Abacatepay::Subscription.create!(
            customer: pay_customer,
            processor_id: "subs_tAFqDWBhcEYTjQh2K0ZYDHau",
            name: "prod_x",
            processor_plan: "prod_x",
            status: "active"
          )
        end

        test "marks subscription canceled with ends_at from payload" do
          SubscriptionCancelled.new.call(fixture)

          @subscription.reload
          assert_equal "canceled", @subscription.status
          assert_equal Time.parse("2026-04-10T14:30:00Z").to_i, @subscription.ends_at.to_i
        end

        test "does not destroy the subscription" do
          assert_no_difference -> { Pay::Subscription.count } do
            SubscriptionCancelled.new.call(fixture)
          end
        end

        test "no-ops when subscription is unknown" do
          @subscription.destroy!

          assert_nothing_raised { SubscriptionCancelled.new.call(fixture) }
        end

        test "is idempotent" do
          handler = SubscriptionCancelled.new
          handler.call(fixture)
          ends_at = @subscription.reload.ends_at

          handler.call(fixture)
          assert_equal ends_at.to_i, @subscription.reload.ends_at.to_i
        end
      end
    end
  end
end
