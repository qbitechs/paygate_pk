# frozen_string_literal: true

module PaygatePk
  # Global gem configuration.
  #
  # Typical Rails usage:
  #   PaygatePk.configure do |c|
  #     c.default_currency = "PKR"
  #
  #     c.pay_fast.environment   = Rails.env.production? ? :production : :sandbox
  #     c.pay_fast.merchant_id   = ENV["PAYFAST_MERCHANT_ID"]
  #     c.pay_fast.secured_key   = ENV["PAYFAST_SECURED_KEY"]
  #     c.pay_fast.merchant_name = "Acme Store"
  #
  #     c.easy_paisa.environment = Rails.env.production? ? :production : :sandbox
  #     c.easy_paisa.username    = ENV["EASYPAISA_USERNAME"]
  #     c.easy_paisa.password    = ENV["EASYPAISA_PASSWORD"]
  #     c.easy_paisa.store_id    = ENV["EASYPAISA_STORE_ID"]
  #     c.easy_paisa.account_num = ENV["EASYPAISA_ACCOUNT"]
  #   end
  #
  # After `configure`, the config object is frozen — mutating it raises.
  class Config
    attr_accessor :default_currency, :timeouts, :retry, :user_agent, :logger
    attr_reader   :pay_fast, :easy_paisa

    def initialize
      @default_currency = "PKR"
      @timeouts         = { open_timeout: 5, read_timeout: 10 }
      @retry            = {
        max: 2, interval: 0.2, backoff_factor: 2.0,
        retry_statuses: [429, 500, 502, 503, 504]
      }
      @user_agent       = "paygate_pk/#{PaygatePk::VERSION}"
      @logger           = nil
      @pay_fast         = PayFastConfig.new
      @easy_paisa       = EasyPaisaConfig.new
      @configured       = false
    end

    # Mark as configured and deep-freeze. Called automatically by
    # PaygatePk.configure after the block runs.
    def freeze!
      @configured = true
      @pay_fast.freeze
      @easy_paisa.freeze
      freeze
      self
    end

    def configured?
      @configured
    end

    # Per-provider config for PayFast.
    #
    # `environment` selects the base URL via PayFast::Endpoints.
    # `base_url` and `api_base_url` can override the env-derived URLs
    # (useful for staging hosts PayFast hands out on request).
    class PayFastConfig
      ENVIRONMENTS = %i[sandbox production].freeze
      DEFAULT_TRAN_TYPE = "ECOMM_PURCHASE"

      attr_accessor :merchant_id, :secured_key, :merchant_name, :store_id,
                    :version_string, :tran_type, :base_url, :api_base_url
      attr_reader :environment

      def initialize
        @environment    = :sandbox
        @merchant_id    = nil
        @secured_key    = nil
        @merchant_name  = nil
        @store_id       = nil
        @version_string = nil
        @tran_type      = DEFAULT_TRAN_TYPE
        @base_url       = nil
        @api_base_url   = nil
      end

      def environment=(env)
        sym = env&.to_sym
        unless ENVIRONMENTS.include?(sym)
          raise ArgumentError,
                "environment must be one of #{ENVIRONMENTS.inspect}, got #{env.inspect}"
        end
        @environment = sym
      end

      # Resolves the host URL used for redirect form action + token API.
      # Explicit base_url wins; otherwise derived from environment.
      def resolved_base_url
        return base_url if base_url

        PaygatePk::PayFast::Endpoints.base_url(environment)
      end
    end

    # Per-provider config for Easypaisa (REST without RSA).
    #
    # Required for any call: username + password + store_id. account_num
    # is required for Inquiry only (it's the merchant's EWP Account #
    # found on the Profile page of the Easypaisa Merchant Portal).
    class EasyPaisaConfig
      ENVIRONMENTS = %i[sandbox production].freeze

      attr_accessor :username, :password, :store_id, :account_num, :base_url
      attr_reader :environment

      def initialize
        @environment = :sandbox
        @username    = nil
        @password    = nil
        @store_id    = nil
        @account_num = nil
        @base_url    = nil
      end

      def environment=(env)
        sym = env&.to_sym
        unless ENVIRONMENTS.include?(sym)
          raise ArgumentError,
                "environment must be one of #{ENVIRONMENTS.inspect}, got #{env.inspect}"
        end
        @environment = sym
      end

      def resolved_base_url
        return base_url if base_url

        PaygatePk::EasyPaisa::Endpoints.base_url(environment)
      end
    end
  end
end
