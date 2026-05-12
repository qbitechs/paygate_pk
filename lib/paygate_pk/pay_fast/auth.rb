# frozen_string_literal: true

module PaygatePk
  module PayFast
    # Server-to-server PayFast token fetch (Merchant Integration Guide
    # v2.3 §3.1). Internal: invoked by Redirect#build. Not advertised
    # on the 1.0 public surface; use Redirect.build, which calls this
    # automatically.
    class Auth
      def self.call(**kwargs)
        new.call(**kwargs)
      end

      def initialize(config: PaygatePk::PayFast.config, http: nil)
        @config = config
        @http   = http
      end

      def call(basket_id:, amount:, currency: nil)
        currency ||= PaygatePk.config.default_currency
        ensure_config!
        ensure_args!(basket_id: basket_id, amount: amount, currency: currency)

        resp  = http.post(Endpoints::GET_ACCESS_TOKEN_PATH, form: payload(basket_id, amount, currency))
        token = extract_token(resp)
        raise PaygatePk::AuthError, "missing ACCESS_TOKEN in PayFast token response" if Coercions.blank?(token)

        Contracts::AccessToken.new(value: token, raw: resp)
      end

      private

      def http
        @http ||= PaygatePk::HTTP::Client.new(
          base_url: @config.resolved_base_url,
          headers: { "Accept" => "application/json" }
        )
      end

      def ensure_config!
        missing = []
        missing << :merchant_id if Coercions.blank?(@config.merchant_id)
        missing << :secured_key if Coercions.blank?(@config.secured_key)
        return if missing.empty?

        raise PaygatePk::ConfigurationError, "PayFast config missing: #{missing.join(", ")}"
      end

      def ensure_args!(basket_id:, amount:, currency:)
        missing = []
        missing << :basket_id if Coercions.blank?(basket_id)
        missing << :amount    if amount.nil?
        missing << :currency  if Coercions.blank?(currency)
        return if missing.empty?

        raise PaygatePk::ValidationError.new(
          "missing required args: #{missing.join(", ")}",
          details: { missing: missing }
        )
      end

      def payload(basket_id, amount, currency)
        {
          "MERCHANT_ID"   => @config.merchant_id,
          "SECURED_KEY"   => @config.secured_key,
          "BASKET_ID"     => basket_id.to_s,
          "TXNAMT"        => Coercions.to_amount_string(amount),
          "CURRENCY_CODE" => currency
        }
      end

      def extract_token(resp)
        return nil unless resp.is_a?(Hash)

        resp["ACCESS_TOKEN"] || resp["access_token"]
      end
    end
  end
end
