# frozen_string_literal: true

module PaygatePk
  # Global configuration for PaygatePk
  class Config
    attr_accessor :logger, :default_currency, :timeouts, :retry, :user_agent
    attr_reader   :payfast

    def initialize
      @logger = nil
      @default_currency = "PKR"
      @timeouts = { open_timeout: 5, read_timeout: 10 }
      @retry = { max: 2, interval: 0.2, backoff_factor: 2.0, retry_statuses: [429, 500, 502, 503, 504] }
      @user_agent = "paygate_pk/#{PaygatePk::VERSION}"

      @payfast = ProviderConfig.new
      @frozen  = false
    end

    def freeze!
      @frozen = true
      self
    end

    def frozen?
      @frozen
    end

    # Provider-specific configuration
    class ProviderConfig
      attr_accessor :base_url, :merchant_id, :secured_key, :checkout_mode, :username, :password, :store_id

      def initialize
        @base_url = nil
        @merchant_id = nil
        @secured_key = nil
        @checkout_mode = :immediate
        @username = nil
        @password = nil
        @store_id = nil
      end
    end
  end
end
