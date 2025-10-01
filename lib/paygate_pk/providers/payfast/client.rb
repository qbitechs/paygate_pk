# frozen_string_literal: true

require_relative "../../http/client"

module PaygatePK
  module Providers
    module Payfast
      # HTTP client for PayFast API
      class Client
        def initialize(config:)
          @config = config
        end

        private

        attr_reader :config

        def http
          raise ConfigurationError, "PayFast base_url not set" unless config.base_url

          PaygatePK::HTTP::Client.new(
            base_url: config.base_url,
            headers: { "Accept" => "application/json" },
            timeouts: PaygatePK.config.timeouts,
            retry_conf: PaygatePK.config.retry,
            logger: PaygatePK.config.logger
          )
        end
      end
    end
  end
end
