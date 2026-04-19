require "test_helper"

module Pay
  module Abacatepay
    class ChargeTest < ActiveSupport::TestCase
      setup do
        user = User.create!(email: "c@x.com", name: "Cliente", document: "111.222.333-44")
        @pay_customer = Pay::Customer.create!(owner: user, processor: "abacatepay", processor_id: "cust_charge1")
      end

      test "STATUS_MAP only maps statuses that become Pay::Charge" do
        assert_equal "paid", Pay::Abacatepay::Charge::STATUS_MAP["PAID"]
        assert_equal "refunded", Pay::Abacatepay::Charge::STATUS_MAP["REFUNDED"]
        assert_equal "disputed", Pay::Abacatepay::Charge::STATUS_MAP["DISPUTED"]
        assert_equal "pending", Pay::Abacatepay::Charge::STATUS_MAP["PENDING"]
        assert_nil Pay::Abacatepay::Charge::STATUS_MAP["EXPIRED"]
        assert_nil Pay::Abacatepay::Charge::STATUS_MAP["CANCELLED"]
      end

      test "#refund! raises Pay::Abacatepay::Error explaining dashboard-only flow" do
        charge = Pay::Abacatepay::Charge.create!(
          customer: @pay_customer,
          processor_id: "chk_refundx",
          amount: 5000,
          currency: "BRL",
          status: "paid"
        )

        error = assert_raises(Pay::Abacatepay::Error) { charge.refund! }
        assert_match(/refund endpoint/, error.message)
        assert_match(/dashboard/, error.message)
      end

      test "#charged_back? reflects status == disputed" do
        charge = Pay::Abacatepay::Charge.create!(
          customer: @pay_customer,
          processor_id: "chk_dispute1",
          amount: 5000,
          currency: "BRL",
          status: "paid"
        )

        assert_not charge.charged_back?
        charge.update!(status: "disputed")
        assert charge.charged_back?
      end

      test "is STI — Pay::Charge.last.type is Pay::Abacatepay::Charge" do
        Pay::Abacatepay::Charge.create!(
          customer: @pay_customer,
          processor_id: "chk_sti1",
          amount: 1000,
          currency: "BRL",
          status: "paid"
        )

        assert_equal "Pay::Abacatepay::Charge", Pay::Charge.last.type
        assert_instance_of Pay::Abacatepay::Charge, Pay::Charge.last
      end

      test ".sync updates existing charge from SDK response" do
        Pay::Abacatepay::Charge.create!(
          customer: @pay_customer,
          processor_id: "chk_sync1",
          amount: 5000,
          currency: "BRL",
          status: "pending"
        )

        stub_request(:get, /checkouts\/get/)
          .to_return(
            status: 200,
            headers: {"Content-Type" => "application/json"},
            body: {
              data: {
                id: "chk_sync1",
                amount: 5000,
                status: "PAID",
                url: "https://app.abacatepay.com/pay/chk_sync1",
                customer: {id: "cust_charge1"}
              }
            }.to_json
          )

        result = Pay::Abacatepay::Charge.sync("chk_sync1")

        assert_equal "paid", result.status
        assert_equal 1, Pay::Abacatepay::Charge.where(processor_id: "chk_sync1").count
      end

      test ".sync returns nil when Pay::Customer not found" do
        stub_request(:get, /checkouts\/get/)
          .to_return(
            status: 200,
            headers: {"Content-Type" => "application/json"},
            body: {
              data: {id: "chk_orphan", amount: 1000, status: "PAID", customer: {id: "cust_unknown"}}
            }.to_json
          )

        assert_nil Pay::Abacatepay::Charge.sync("chk_orphan")
      end
    end
  end
end
