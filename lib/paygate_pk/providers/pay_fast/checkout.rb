# lib/paygate_pk/providers/pay_fast/checkout.rb
# frozen_string_literal: true

require "securerandom"
require "date"
require "nokogiri"

module PaygatePk
  module Providers
    module PayFast
      # Builds and submits a hosted checkout request to PayFast.
      #
      # Usage:
      #   client   = PaygatePk::Providers::PayFast::Checkout.new(config: PaygatePk.config.payfast)
      #   checkout = client.create!(
      #     token: token.token,
      #     basket_id: "B-1001",
      #     amount: 1500,
      #     customer: { mobile: "03xxxxxxxxx", email: "buyer@example.com" },
      #     success_url: "...",
      #     failure_url: "...",
      #     description: "Order #1001",
      #     checkout_mode: :immediate
      #   )
      class Checkout < Client
        ENDPOINT = "/Ecommerce/api/Transaction/PostTransaction"

        REQUIRED_ROOT_KEYS     = %i[token basket_id amount success_url failure_url description].freeze
        REQUIRED_CUSTOMER_KEYS = %i[mobile email].freeze

        # Creates a hosted checkout via PayFast.
        #
        # @param token [String] ACCESS_TOKEN from GetAccessToken
        # @param basket_id [String]
        # @param amount [Integer, Float] rupees
        # @param customer [Hash] keys: :mobile, :email
        # @param success_url [String]
        # @param failure_url [String]
        # @param description [String] TXNDESC
        # @param order_date [Date] defaults: Date.today
        # @param checkout_mode [Symbol] :immediate or :delayed (defaults from config)
        # @param endpoint [Symbol] default to ENDPOINT constant

        # @return [PaygatePk::Contracts::HostedCheckout]
        def create!(opts: {})
          validate_config!
          validate_args!(opts)

          form = build_form(opts)

          response = http.post(opts[:endpoint] || ENDPOINT, form: form)

          if response
            doc = Nokogiri::HTML(response)
            url = doc.at("a")["href"] if doc.at("a")
          end

          PaygatePk::Contracts::HostedCheckout.new(
            provider: :payfast,
            basket_id: opts[:basket_id],
            amount: opts[:amount],
            url: url
          )
        end

        private

        # -- Validation ---------------------------------------------------------

        def validate_config!
          missing = []
          missing << :merchant_id if blank?(config.merchant_id)
          missing << :secured_key if blank?(config.secured_key)
          raise PaygatePk::ConfigurationError, "PayFast config missing: #{missing.join(", ")}" unless missing.empty?
        end

        def validate_args!(opts)
          missing = []
          REQUIRED_ROOT_KEYS.each do |k|
            v = opts[k]
            missing << k if k == :amount ? opts[:amount].nil? : blank?(v)
          end
          REQUIRED_CUSTOMER_KEYS.each { |k| missing << :"customer.#{k}" if blank?(opts[:customer][k]) }
          raise PaygatePk::ValidationError, "missing required args: #{missing.join(", ")}" unless missing.empty?
        end

        # -- Builders -----------------------------------------------------------

        def build_form(opts)
          {
            "MERCHANT_ID" => config.merchant_id,
            "MERCHANT_NAME" => merchant_name_default,
            "TOKEN" => opts[:token],
            "PROCCODE" => "00",
            "TXNAMT" => opts[:amount].to_s,
            "CUSTOMER_MOBILE_NO" => opts[:customer][:mobile],
            "CUSTOMER_EMAIL_ADDRESS" => opts[:customer][:email],
            "SIGNATURE" => SecureRandom.hex(16),
            "VERSION" => PaygatePk::VERSION,
            "TXNDESC" => opts[:description],
            "SUCCESS_URL" => opts[:success_url],
            "FAILURE_URL" => opts[:failure_url],
            "BASKET_ID" => opts[:basket_id],
            "ORDER_DATE" => Date.today,
            "CHECKOUT_URL" => normalize_checkout_mode(opts[:checkout_mode] || config.checkout_mode),
            "CURRENCY_CODE" => PaygatePk.config.default_currency
          }
        end

        # -- Helpers ------------------------------------------------------------

        def normalize_checkout_mode(mode)
          case mode&.to_sym
          when :delayed then "DELAYED"
          when :immediate, nil then "IMMEDIATE"
          else
            # Be lenient but explicit: unknown symbols fall back to IMMEDIATE
            "IMMEDIATE"
          end
        end

        def merchant_name_default
          # Kept blank as many integrations treat it as optional; override here
          # later if you decide to expose it via config.
          ""
        end

        def blank?(value)
          value.nil? || (value.respond_to?(:empty?) && value.empty?)
        end
      end
    end
  end
end
