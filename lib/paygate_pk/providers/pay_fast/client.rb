# frozen_string_literal: true

require_relative "../../http/client"
require_relative "../../version"

module PaygatePk
  module Providers
    module PayFast
      # HTTP client for PayFast API
      class Client
        def initialize(config: PaygatePk.config.pay_fast)
          @config = config
        end

        private

        attr_reader :config

        def http
          raise ConfigurationError, "PayFast base_url not set" unless config.base_url

          PaygatePk::HTTP::Client.new(
            base_url: config.base_url,
            headers: { "Accept" => "application/json" },
            timeouts: PaygatePk.config.timeouts,
            retry_conf: PaygatePk.config.retry,
            logger: PaygatePk.config.logger
          )
        end
      end
    end
  end
end
