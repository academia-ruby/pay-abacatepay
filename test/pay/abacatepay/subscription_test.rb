require "test_helper"

module Pay
  module Abacatepay
    class SubscriptionTest < ActiveSupport::TestCase
      CANCEL_URL = "https://api.abacatepay.com/v2/subscriptions/cancel"
      GET_URL = "https://api.abacatepay.com/v2/subscriptions/get"

      setup do
        @user = User.create!(email: "sub@example.com", name: "Sub User", document: "111.222.333-44")
        @pay_customer = Pay::Customer.create!(
          owner: @user,
          processor: "abacatepay",
          processor_id: "cust_sub1"
        )
        @subscription = Pay::Abacatepay::Subscription.create!(
          customer: @pay_customer,
          processor_id: "subs_1",
          name: "prod_x",
          processor_plan: "prod_x",
          status: "active"
        )
      end

      test "cancel_now! hits POST /subscriptions/cancel and updates local record" do
        stub = stub_request(:post, /#{Regexp.escape(CANCEL_URL)}/o)
          .to_return(
            status: 200,
            headers: {"Content-Type" => "application/json"},
            body: {data: {id: "subs_1", status: "CANCELLED"}}.to_json
          )

        @subscription.cancel_now!

        assert_requested stub
        @subscription.reload
        assert_equal "canceled", @subscription.status
        assert @subscription.ends_at.present?
      end

      test "cancel delegates to cancel_now! with a warning" do
        stub = stub_request(:post, /#{Regexp.escape(CANCEL_URL)}/o)
          .to_return(
            status: 200,
            headers: {"Content-Type" => "application/json"},
            body: {data: {id: "subs_1", status: "CANCELLED"}}.to_json
          )

        captured = StringIO.new
        original = Rails.logger
        Rails.logger = Logger.new(captured)

        begin
          @subscription.cancel
        ensure
          Rails.logger = original
        end

        assert_requested stub
        assert_match(/cancel-at-period-end/, captured.string)
      end

      test "cancel_now! wraps SDK errors in Pay::Abacatepay::Error" do
        stub_request(:post, /#{Regexp.escape(CANCEL_URL)}/o)
          .to_return(
            status: 400,
            headers: {"Content-Type" => "application/json"},
            body: {error: "no such subscription"}.to_json
          )

        assert_raises(Pay::Abacatepay::Error) { @subscription.cancel_now! }
      end

      test "resume raises NotImplementedError" do
        assert_raises(NotImplementedError) { @subscription.resume }
      end

      test "swap raises NotImplementedError" do
        assert_raises(NotImplementedError) { @subscription.swap("other_plan") }
      end

      test "change_quantity raises NotImplementedError" do
        assert_raises(NotImplementedError) { @subscription.change_quantity(2) }
      end

      test "past_due? always returns false" do
        @subscription.update!(status: "past_due")
        refute @subscription.past_due?
      end

      test "api_record fetches from the SDK" do
        stub = stub_request(:get, /#{Regexp.escape(GET_URL)}/o)
          .to_return(
            status: 200,
            headers: {"Content-Type" => "application/json"},
            body: {data: {id: "subs_1", status: "ACTIVE"}}.to_json
          )

        @subscription.api_record

        assert_requested stub
      end
    end
  end
end
