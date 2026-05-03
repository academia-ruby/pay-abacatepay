module Pay
  module Abacatepay
    class Subscription < Pay::Subscription
      STATUS_FROM_EVENT = {
        "subscription.completed" => "active",
        "subscription.renewed" => "active",
        "subscription.cancelled" => "canceled"
      }.freeze

      def self.sync(processor_id, event: nil)
        return if processor_id.blank?

        subscription = Pay::Abacatepay::Subscription.find_by(processor_id: processor_id)
        customer = subscription&.customer
        customer ||= Pay::Customer.find_by(processor: "abacatepay", processor_id: event&.customer_id) if event

        if customer.nil?
          Rails.logger.warn("[pay-abacatepay] cannot sync subscription #{processor_id}: Pay::Customer not found")
          return
        end

        subscription ||= Pay::Abacatepay::Subscription.new(customer: customer, processor_id: processor_id)
        assign_attributes_from(subscription, event) if event
        subscription.save!
        subscription
      end

      def self.assign_attributes_from(subscription, event)
        status = STATUS_FROM_EVENT[event.type] || subscription.status || "active"
        period_start = event.paid_at || event.subscription_created_at || Time.current
        interval = event.interval

        subscription.assign_attributes(
          name: event.product_id || subscription.name || "default",
          processor_plan: event.product_id || subscription.processor_plan || "default",
          status: status,
          current_period_start: period_start,
          current_period_end: interval ? period_start + interval : subscription.current_period_end,
          ends_at: (status == "canceled") ? (event.canceled_at || Time.current) : subscription.ends_at
        )
      end
      private_class_method :assign_attributes_from

      def cancel(**options)
        Rails.logger.warn(
          "[pay-abacatepay] AbacatePay does not support cancel-at-period-end; cancelling immediately"
        )
        cancel_now!(**options)
      end

      def cancel_now!(**_options)
        ::AbacatePay.subscriptions.send(:request, "POST", "cancel", params: {id: processor_id})
        update!(status: "canceled", ends_at: Time.current)
      rescue ::AbacatePay::Error => e
        raise Pay::Abacatepay::Error, e.message
      end

      def resume
        raise NotImplementedError,
          "AbacatePay does not support resuming cancelled subscriptions; create a new subscription"
      end

      def swap(_plan, **_options)
        raise NotImplementedError,
          "AbacatePay does not support plan swap; cancel the subscription and create a new one"
      end

      def change_quantity(_quantity, **_options)
        raise NotImplementedError,
          "AbacatePay does not support quantity changes"
      end

      # AbacatePay does not emit payment-failure events, so we cannot observe
      # a past_due state. Always false.
      def past_due?
        false
      end

      def api_record
        ::AbacatePay.subscriptions.send(:request, "GET", "get", params: {id: processor_id})
      rescue ::AbacatePay::Error => e
        raise Pay::Abacatepay::Error, e.message
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_abacatepay_subscription, Pay::Abacatepay::Subscription
