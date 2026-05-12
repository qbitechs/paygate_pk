# frozen_string_literal: true

require "rails/railtie"
require_relative "view_helpers"

module PaygatePk
  module Rails
    # Wires ViewHelpers into ActionView when the gem boots inside a
    # Rails app. Loaded conditionally from lib/paygate_pk.rb so that
    # non-Rails consumers don't have to install Rails to use the gem.
    class Railtie < ::Rails::Railtie
      initializer "paygate_pk.view_helpers" do
        ActiveSupport.on_load(:action_view) do
          include PaygatePk::Rails::ViewHelpers
        end
      end
    end
  end
end
