require "test_helper"

module Pay
  module Abacatepay
    module Webhooks
      class EventTest < ActiveSupport::TestCase
        FIXTURES = File.expand_path("../../../fixtures/webhooks", __dir__)

        def fixture(name)
          JSON.parse(File.read(File.join(FIXTURES, "#{name}.json")))
        end

        test "exposes top-level envelope fields" do
          event = Event.new(fixture("subscription_renewed"))

          assert_equal "log_abc123xyz", event.id
          assert_equal "subscription.renewed", event.type
          assert_equal 2, event.api_version
          refute event.dev_mode?
        end

        test "exposes subscription accessors" do
          event = Event.new(fixture("subscription_renewed"))

          assert_equal "subs_tAFqDWBhcEYTjQh2K0ZYDHau", event.subscription_id
          assert_equal "ACTIVE", event.subscription_status
          assert_equal 2990, event.subscription_amount_cents
          assert_equal "BRL", event.subscription_currency
          assert_equal "MONTHLY", event.frequency
          assert_equal 1.month, event.interval
          assert_nil event.canceled_at
        end

        test "exposes customer accessors" do
          event = Event.new(fixture("subscription_renewed"))

          assert_equal "cust_def456", event.customer_id
          assert_equal "maria@exemplo.com", event.customer_email
          assert_equal "Maria Santos", event.customer_name
          assert_equal "12345678000190", event.customer_tax_id
        end

        test "exposes payment accessors for renewed" do
          event = Event.new(fixture("subscription_renewed"))

          assert_equal "char_xyz789", event.charge_id
          assert_equal 2990, event.charge_amount_cents
          assert_equal 2990, event.paid_amount_cents
          assert_equal 100, event.platform_fee_cents
          assert_equal "PAID", event.charge_status
          assert_kind_of Time, event.paid_at
        end

        test "exposes checkout accessors" do
          event = Event.new(fixture("subscription_renewed"))

          assert_equal "bill_renewxyz789", event.checkout_id
          assert_equal "prod_bx4BstRWhQ2SUcKsPt4c6pmq", event.product_id
        end

        test "returns nil on missing fields (cancelled has no payment/checkout)" do
          event = Event.new(fixture("subscription_cancelled"))

          assert_nil event.charge_id
          assert_nil event.charge_amount_cents
          assert_nil event.paid_at
          assert_nil event.checkout_id
          assert_nil event.product_id
          assert_kind_of Time, event.canceled_at
        end

        test "is tolerant to empty hash" do
          event = Event.new({})

          assert_nil event.id
          assert_nil event.type
          assert_equal({}, event.data)
          assert_equal "BRL", event.subscription_currency
          assert_nil event.interval
        end

        test "unknown frequency returns nil interval" do
          event = Event.new({"data" => {"subscription" => {"frequency" => "BIWEEKLY"}}})

          assert_nil event.interval
        end

        test "preserves raw hash" do
          raw = fixture("subscription_renewed")
          event = Event.new(raw)

          assert_equal raw, event.raw
        end
      end
    end
  end
end
