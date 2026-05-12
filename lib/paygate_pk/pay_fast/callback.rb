# frozen_string_literal: true

module PaygatePk
  module PayFast
    # Verifies the IPN / browser-return notification PayFast sends to
    # SUCCESS_URL, FAILURE_URL, or the configured CHECKOUT_URL.
    #
    # Per Merchant Integration Guide v2.3 §3.2.3:
    # - PayFast posts/redirects with mixed-case keys: `basket_id`,
    #   `err_code`, `validation_hash` are lower; `Instrument_token`,
    #   `Recurring_txn`, `PaymentName` are PascalCase. We down-case
    #   everything internally so consumers don't have to care.
    # - validation_hash = SHA256("basket_id|secured_key|merchant_id|err_code")
    #   compared in constant time via Util::Security.secure_compare.
    #
    # Returns Contracts::CallbackEvent on success, raises SignatureError
    # on missing fields or hash mismatch.
    class Callback
      REQUIRED_KEYS = %w[basket_id err_code validation_hash].freeze
      SUCCESS_CODE  = "000"

      def self.verify!(params, config: PaygatePk::PayFast.config)
        new(config: config).verify!(params)
      end

      def initialize(config: PaygatePk::PayFast.config)
        @config = config
      end

      def verify!(raw_params)
        params = normalize_keys(raw_params)
        ensure_required!(params)
        ensure_signature!(params)
        build_event(params, raw_params)
      end

      private

      def normalize_keys(hash)
        # ActionController::Parameters and HashWithIndifferentAccess both
        # respond to #to_h; fall back to dup for plain Hashes.
        source = hash.respond_to?(:to_unsafe_h) ? hash.to_unsafe_h : hash.to_h
        source.transform_keys { |k| k.to_s.downcase }
      end

      def ensure_required!(params)
        missing = REQUIRED_KEYS.select { |k| Coercions.blank?(params[k]) }
        return if missing.empty?

        raise PaygatePk::SignatureError, "missing required callback param(s): #{missing.join(", ")}"
      end

      def ensure_signature!(params)
        expected = PaygatePk::Util::Signature::PayFast.validation_hash(
          basket_id: params["basket_id"],
          merchant_secret_key: @config.secured_key,
          merchant_id: @config.merchant_id,
          payfast_err_code: params["err_code"]
        )
        return if PaygatePk::Util::Security.secure_compare(expected, params["validation_hash"].to_s)

        raise PaygatePk::SignatureError, "invalid validation_hash"
      end

      def build_event(params, raw)
        Contracts::CallbackEvent.new(
          provider: :pay_fast,
          transaction_id: params["transaction_id"],
          basket_id: params["basket_id"],
          order_date: params["order_date"],
          approved: params["err_code"] == SUCCESS_CODE,
          code: params["err_code"],
          message: params["err_msg"],
          amount: params["transaction_amount"],
          merchant_amount: params["merchant_amount"],
          discounted_amount: params["discounted_amount"],
          currency: params["transaction_currency"],
          payment_method: params["paymentname"],
          instrument_token: params["instrument_token"],
          recurring: truthy?(params["recurring_txn"]),
          raw: raw
        )
      end

      def truthy?(value)
        return false if value.nil?

        %w[true 1 yes].include?(value.to_s.downcase)
      end
    end
  end
end
