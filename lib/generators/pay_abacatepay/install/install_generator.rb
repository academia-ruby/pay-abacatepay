require "rails/generators"
require "rails/generators/active_record"

module PayAbacatepay
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Copies pay-abacatepay migrations into the host application."

      def copy_migrations
        migration_template(
          "create_pay_abacatepay_processed_webhooks.rb.tt",
          "db/migrate/create_pay_abacatepay_processed_webhooks.rb"
        )
      end
    end
  end
end
