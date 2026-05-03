module Pay
  module Abacatepay
    class ProcessedWebhook < ActiveRecord::Base
      self.table_name = "pay_abacatepay_processed_webhooks"

      validates :event_type, :event_id, presence: true

      def self.process!(event_type:, event_id:)
        transaction(requires_new: true) do
          create!(event_type: event_type, event_id: event_id, processed_at: Time.current)
          yield if block_given?
        end
        nil
      rescue ActiveRecord::RecordNotUnique
        :already_processed
      end
    end
  end
end
