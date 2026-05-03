require "test_helper"

module Pay
  module Abacatepay
    module Webhooks
      class CheckoutCompletedTest < ActiveSupport::TestCase
        def one_time_fixture
          JSON.parse(File.read(File.expand_path("../../../fixtures/webhooks/checkout_completed_one_time.json", __dir__)))
        end

        def subscription_fixture
          JSON.parse(File.read(File.expand_path("../../../fixtures/webhooks/checkout_completed_subscription.json", __dir__)))
        end

        setup do
          user = User.create!(email: "m@x.com", name: "Maria", document: "111.222.333-44")
          @pay_customer = Pay::Customer.create!(owner: user, processor: "abacatepay", processor_id: "cust_def456")
        end

        test "one-time checkout creates a Pay::Abacatepay::Charge" do
          CheckoutCompleted.new.call(one_time_fixture)

          charge = Pay::Abacatepay::Charge.find_by!(processor_id: "chk_onetime789")
          assert_equal 5000, charge.amount
          assert_equal "BRL", charge.currency
          assert_equal 150, charge.application_fee_amount
          assert_equal "paid", charge.status
          assert_equal @pay_customer.id, charge.customer_id
          assert_nil charge.subscription_id
        end

        test "created charge is STI — type is Pay::Abacatepay::Charge" do
          CheckoutCompleted.new.call(one_time_fixture)

          assert_equal "Pay::Abacatepay::Charge", Pay::Charge.last.type
        end

        test "subscription checkout is skipped — no charge created" do
          assert_no_difference -> { Pay::Charge.count } do
            CheckoutCompleted.new.call(subscription_fixture)
          end
        end

        test "is idempotent — second delivery produces no extra charge" do
          handler = CheckoutCompleted.new
          handler.call(one_time_fixture)

          assert_no_difference -> { Pay::Charge.count } do
            handler.call(one_time_fixture)
          end
        end

        test "logs warning and no-ops when Pay::Customer is unknown" do
          @pay_customer.destroy!

          assert_no_difference -> { Pay::Charge.count } do
            CheckoutCompleted.new.call(one_time_fixture)
          end
        end

        test "updates a pre-existing pending charge (Customer#charge → webhook flow)" do
          Pay::Abacatepay::Charge.create!(
            customer: @pay_customer,
            processor_id: "chk_onetime789",
            amount: 5000,
            currency: "BRL",
            status: "pending"
          )

          CheckoutCompleted.new.call(one_time_fixture)

          assert_equal 1, Pay::Abacatepay::Charge.where(processor_id: "chk_onetime789").count
          assert_equal "paid", Pay::Abacatepay::Charge.find_by(processor_id: "chk_onetime789").status
        end

        test "preserves app-level metadata when transitioning a pending charge to paid" do
          Pay::Abacatepay::Charge.create!(
            customer: @pay_customer,
            processor_id: "chk_onetime789",
            amount: 5000,
            currency: "BRL",
            status: "pending",
            metadata: {"release_id" => 42, "release_slug" => "release-x"}
          )

          CheckoutCompleted.new.call(one_time_fixture)

          charge = Pay::Abacatepay::Charge.find_by!(processor_id: "chk_onetime789")
          assert_equal "paid", charge.status
          assert_equal 42, charge.metadata["release_id"]
          assert_equal "release-x", charge.metadata["release_slug"]
        end
      end
    end
  end
end
