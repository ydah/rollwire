# frozen_string_literal: true

module Rollwire
  class Railtie < Rails::Railtie
    initializer "rollwire.configure" do
      Rollwire.configuration.apply_environment_default!(test: Rails.env.test?)

      ActiveSupport.on_load(:active_record) do
        Rollwire.install!
      end
    end
  end
end
