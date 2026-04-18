require "rails/engine"

module Pay
  module Abacatepay
    class Engine < ::Rails::Engine
      engine_name "pay_abacatepay"

      initializer "pay_abacatepay.register_processor" do
        Pay.enabled_processors << :abacatepay unless Pay.enabled_processors.include?(:abacatepay)
      end

      initializer "pay_abacatepay.attributes" do
        ActiveSupport.on_load(:active_record) do
          include Pay::Attributes
        end
      end

      initializer "pay_abacatepay.routes" do
        Pay::Engine.routes.append do
          post "webhooks/abacatepay", to: "pay/webhooks/abacatepay#create"
        end
      end

      config.before_initialize do
        Pay::Abacatepay.configure_webhooks if Pay::Abacatepay.enabled?
      end

      config.to_prepare do
        Pay::Abacatepay.setup if Pay::Abacatepay.enabled? && Pay::Abacatepay.api_key
      end
    end
  end
end
