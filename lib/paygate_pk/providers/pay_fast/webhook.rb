# frozen_string_literal: true

require "rack/utils"

module PaygatePk
  module Providers
    module PayFast
      # Verifies PayFast IPN/notification params (GET to your CHECKOUT_URL)
      # Returns PaygatePk::Contracts::WebhookEvent on success, raises on failure.
      class Webhook
        def verify!(raw_params)
          validate_required_params

          params = normalize_keys(raw_params)
          verify_signature(params)
          build_webhook(params, raw_params)
        end

        private

        def verify_signature(params)
          expected = PaygatePk::Util::Signature::Payfast.validation_hash(
            basket_id: params["basket_id"],
            merchant_secret_key: config.secured_key,
            merchant_id: config.merchant_id,
            payfast_err_code: params["err_code"]
          )
          return if Rack::Utils.secure_compare(expected, params["validation_hash"])

          raise PaygatePk::SignatureError, "invalid validation_hash"
        end

        def validate_required_params
          %w[basket_id err_code validation_hash].each do |k|
            raise PaygatePk::SignatureError, "missing #{k}" unless present?(params[k])
          end
        end

        def normalize_keys(hash)
          hash.transform_keys(&:to_s).tap do |x|
            # common aliases to lowercase
            x["instrument_token"] ||= x["Instrument_token"]
            x["recurring_txn"]    ||= x["Recurring_txn"] || x["RECURRING_TXN"]
          end
        end

        def present?(val)
          !(v.nil? || (val.respond_to?(:empty?) && val.empty?))
        end

        def truthy?(val)
          [true, "true", "TRUE", "1", 1].include?(val)
        end

        def build_webhook(params, raw_params)
          PaygatePk::Contracts::WebhookEvent.new(
            provider: :payfast,
            transaction_id: params["transaction_id"],
            basket_id: params["basket_id"],
            order_date: params["order_date"],
            approved: params["err_code"] == "000",
            code: params["err_code"],
            message: params["err_msg"],
            amount: params["amount"],
            currency: params["currency"],
            instrument_token: params["instrument_token"] || params["Instrument_token"],
            recurring: truthy?(params["recurring_txn"]) || truthy?(params["RECURRING_TXN"]),
            raw: raw_params
          )
        end
      end
    end
  end
end
