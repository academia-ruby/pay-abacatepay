require "test_helper"

module Pay
  module Abacatepay
    class ProcessedWebhookTest < ActiveSupport::TestCase
      test "records the event and yields the block on first call" do
        yielded = false

        result = ProcessedWebhook.process!(event_type: "subscription.renewed", event_id: "log_1") do
          yielded = true
        end

        assert yielded
        assert_nil result
        assert_equal 1, ProcessedWebhook.where(event_type: "subscription.renewed", event_id: "log_1").count
      end

      test "returns :already_processed and does not yield on duplicate" do
        ProcessedWebhook.create!(event_type: "subscription.renewed", event_id: "log_1", processed_at: Time.current)
        yielded = false

        result = ProcessedWebhook.process!(event_type: "subscription.renewed", event_id: "log_1") do
          yielded = true
        end

        refute yielded
        assert_equal :already_processed, result
        assert_equal 1, ProcessedWebhook.where(event_type: "subscription.renewed", event_id: "log_1").count
      end

      test "distinct event_type + event_id pairs are independent" do
        ProcessedWebhook.process!(event_type: "subscription.renewed", event_id: "log_1") {}
        ProcessedWebhook.process!(event_type: "subscription.completed", event_id: "log_1") {}
        ProcessedWebhook.process!(event_type: "subscription.renewed", event_id: "log_2") {}

        assert_equal 3, ProcessedWebhook.count
      end

      test "rolls back the insert when the block raises" do
        assert_raises(RuntimeError) do
          ProcessedWebhook.process!(event_type: "subscription.renewed", event_id: "log_rollback") do
            raise "boom"
          end
        end

        assert_equal 0, ProcessedWebhook.where(event_id: "log_rollback").count
      end
    end
  end
end
