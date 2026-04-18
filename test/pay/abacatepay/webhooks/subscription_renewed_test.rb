require "test_helper"

module Pay
  module Abacatepay
    module Webhooks
      class SubscriptionRenewedTest < ActiveSupport::TestCase
        def fixture
          JSON.parse(File.read(File.expand_path("../../../fixtures/webhooks/subscription_renewed.json", __dir__)))
        end

        setup do
          user = User.create!(email: "m@x.com", name: "Maria", document: "111.222.333-44")
          @pay_customer = Pay::Customer.create!(owner: user, processor: "abacatepay", processor_id: "cust_def456")
          @subscription = Pay::Abacatepay::Subscription.create!(
            customer: @pay_customer,
            processor_id: "subs_tAFqDWBhcEYTjQh2K0ZYDHau",
            name: "prod_bx4BstRWhQ2SUcKsPt4c6pmq",
            processor_plan: "prod_bx4BstRWhQ2SUcKsPt4c6pmq",
            status: "active",
            current_period_start: Time.parse("2024-12-06T20:00:00Z"),
            current_period_end: Time.parse("2025-01-06T20:00:00Z")
          )
        end

        test "creates Pay::Charge and advances the period" do
          SubscriptionRenewed.new.call(fixture)

          charge = @pay_customer.charges.find_by!(processor_id: "char_xyz789")
          assert_equal 2990, charge.amount
          assert_equal @subscription.id, charge.subscription_id
          assert_equal 100, charge.application_fee_amount

          @subscription.reload
          assert_equal Time.parse("2025-01-06T20:00:05Z").to_i, @subscription.current_period_start.to_i
          assert_equal (Time.parse("2025-01-06T20:00:05Z") + 1.month).to_i, @subscription.current_period_end.to_i
        end

        test "is idempotent — second call creates no extra charge" do
          handler = SubscriptionRenewed.new
          handler.call(fixture)

          assert_no_difference -> { Pay::Charge.count } do
            handler.call(fixture)
          end
        end

        test "handles out-of-order: renewed before completed (no existing subscription)" do
          @subscription.destroy!

          SubscriptionRenewed.new.call(fixture)

          subscription = Pay::Abacatepay::Subscription.find_by!(processor_id: "subs_tAFqDWBhcEYTjQh2K0ZYDHau")
          assert_equal "active", subscription.status
          assert_equal 1, @pay_customer.charges.where(processor_id: "char_xyz789").count
        end
      end
    end
  end
end
