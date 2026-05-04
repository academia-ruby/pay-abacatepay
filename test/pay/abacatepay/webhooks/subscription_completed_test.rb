require "test_helper"

module Pay
  module Abacatepay
    module Webhooks
      class SubscriptionCompletedTest < ActiveSupport::TestCase
        def fixture
          JSON.parse(File.read(File.expand_path("../../../fixtures/webhooks/subscription_completed.json", __dir__)))
        end

        setup do
          user = User.create!(email: "m@x.com", name: "Maria", document: "111.222.333-44")
          @pay_customer = Pay::Customer.create!(owner: user, processor: "abacatepay", processor_id: "cust_def456")
        end

        test "creates Pay::Subscription and Pay::Charge for the existing customer" do
          SubscriptionCompleted.new.call(fixture)

          subscription = @pay_customer.subscriptions.find_by!(processor_id: "subs_tAFqDWBhcEYTjQh2K0ZYDHau")
          charge = @pay_customer.charges.find_by!(processor_id: "char_first789")

          assert_equal "active", subscription.status
          assert_equal "prod_bx4BstRWhQ2SUcKsPt4c6pmq", subscription.processor_plan
          assert subscription.current_period_start.present?
          assert subscription.current_period_end.present?
          assert_equal 2990, charge.amount
          assert_equal "BRL", charge.currency
          assert_equal 100, charge.application_fee_amount
          assert_equal subscription.id, charge.subscription_id
        end

        test "no-ops when Pay::Customer is missing" do
          @pay_customer.destroy!

          assert_no_difference ["Pay::Subscription.count", "Pay::Charge.count"] do
            SubscriptionCompleted.new.call(fixture)
          end
        end

        test "is idempotent via ProcessedWebhook — second call creates no extra records" do
          handler = SubscriptionCompleted.new
          handler.call(fixture)

          assert_no_difference ["Pay::Subscription.count", "Pay::Charge.count"] do
            handler.call(fixture)
          end

          assert_equal 1, ProcessedWebhook.where(event_id: "log_completed_abc123").count
        end

        test "records the ProcessedWebhook entry" do
          SubscriptionCompleted.new.call(fixture)

          entry = ProcessedWebhook.find_by!(event_type: "subscription.completed", event_id: "log_completed_abc123")
          assert entry.processed_at.present?
        end

        # Cross-flow with Customer#subscribe: when the eager record exists from
        # subscribe (status "incomplete"), the webhook updates the same row to
        # "active" and rewrites period_*. No duplicate Pay::Subscription.
        test "updates an eager Pay::Subscription created by Customer#subscribe in place" do
          eager = Pay::Abacatepay::Subscription.create!(
            customer: @pay_customer,
            processor_id: "subs_tAFqDWBhcEYTjQh2K0ZYDHau",
            name: "Pro",
            processor_plan: "prod_bx4BstRWhQ2SUcKsPt4c6pmq",
            status: "incomplete",
            current_period_start: Time.current,
            current_period_end: nil
          )

          assert_no_difference "Pay::Subscription.count" do
            SubscriptionCompleted.new.call(fixture)
          end

          eager.reload
          assert_equal "active", eager.status
          assert eager.current_period_end.present?
          assert_equal "prod_bx4BstRWhQ2SUcKsPt4c6pmq", eager.processor_plan
        end
      end
    end
  end
end
