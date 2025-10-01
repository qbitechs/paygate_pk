# frozen_string_literal: true

require "date"

module PaygatePk
  module Providers
    module PayFast
      # Auth client for PayFast API
      class Auth < Client
        ENDPOINT = "/Ecommerce/api/Transaction/GetAccessToken"

        # Returns Contracts::AccessToken
        # Required by PayFast: MERCHANT_ID, SECURED_KEY, BASKET_ID, TXNAMT, CURRENCY_CODE
        #
        def get_access_token(basket_id:, amount:, currency: PaygatePk.config.default_currency, endpoint: ENDPOINT)
          ensure_config!
          ensure_args!(basket_id: basket_id, amount: amount, currency: currency)

          # Guide endpoint: .../Ecommerce/api/Transaction/GetAccessToken
          resp  = http.post(endpoint,
                            form: payload(basket_id, amount, currency))
          token = resp.is_a?(Hash) ? (resp["ACCESS_TOKEN"] || resp["access_token"]) : nil
          raise AuthError, "missing ACCESS_TOKEN in response" unless token

          Contracts::AccessToken.new(token: token, raw: resp)
        end

        private

        def ensure_config!
          missing = []
          missing << :merchant_id if @config.merchant_id.to_s.strip.empty?
          missing << :secured_key if @config.secured_key.to_s.strip.empty?
          raise ConfigurationError, "PayFast config missing: #{missing.join(", ")}" unless missing.empty?
        end

        def ensure_args!(basket_id:, amount:, currency:)
          missing = []
          missing << :basket_id if basket_id.to_s.strip.empty?
          missing << :amount if amount.nil?
          missing << :currency if currency.to_s.strip.empty?
          raise ValidationError, "missing required args: #{missing.join(", ")}" unless missing.empty?
        end

        def payload(basket_id, amount, currency)
          {
            "MERCHANT_ID" => @config.merchant_id,
            "SECURED_KEY" => @config.secured_key,
            "BASKET_ID" => basket_id,
            "TXNAMT" => amount.to_s,
            "CURRENCY_CODE" => currency
          }
        end
      end
    end
  end
end
