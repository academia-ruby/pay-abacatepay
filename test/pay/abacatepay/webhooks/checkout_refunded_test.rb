require "test_helper"

module Pay
  module Abacatepay
    module Webhooks
      class CheckoutRefundedTest < ActiveSupport::TestCase
        def fixture
          JSON.parse(File.read(File.expand_path("../../../fixtures/webhooks/checkout_refunded.json", __dir__)))
        end

        setup do
          user = User.create!(email: "m@x.com", name: "Maria", document: "111.222.333-44")
          @pay_customer = Pay::Customer.create!(owner: user, processor: "abacatepay", processor_id: "cust_def456")
          @charge = Pay::Abacatepay::Charge.create!(
            customer: @pay_customer,
            processor_id: "chk_onetime789",
            amount: 5000,
            currency: "BRL",
            status: "paid"
          )
        end

        test "updates amount_refunded and status" do
          CheckoutRefunded.new.call(fixture)

          @charge.reload
          assert_equal 5000, @charge.amount_refunded
          assert_equal "refunded", @charge.status
          assert @charge.refunded?
          assert @charge.full_refund?
        end

        test "is idempotent — second delivery is a no-op" do
          handler = CheckoutRefunded.new
          handler.call(fixture)
          before = @charge.reload.updated_at

          handler.call(fixture)

          assert_equal before.to_i, @charge.reload.updated_at.to_i
        end

        test "logs warning and no-ops when charge is unknown" do
          @charge.destroy!

          assert_nothing_raised do
            CheckoutRefunded.new.call(fixture)
          end
          assert_equal 0, Pay::Abacatepay::Charge.count
        end
      end
    end
  end
end
