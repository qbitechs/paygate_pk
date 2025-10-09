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

        def get_access_token(**params)
          Auth.new(config: @config).get_access_token(**params)
        end

        def verify_ipn!(params)
          Webhook.new(config: @config).verify!(params)
        end

        def create_checkout(**params)
          Checkout.new(config: @config).create!(**params)
        end

        def get_bearer_token(**params)
          Tokenization::Token.new(config: @config).get(**params)
        end

        def instruments(**params)
          Tokenization::Instrument.new(config: @config).list(**params)
        end

        private

        attr_reader :config

        def http
          raise ConfigurationError, "PayFast base_url not set" unless config.base_url

          PaygatePk::HTTP::Client.new(
            base_url: base_url,
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
