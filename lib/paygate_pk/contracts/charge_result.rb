# frozen_string_literal: true

module PaygatePk
  module Contracts
    # Returned by every "create a charge / take a payment" call against a
    # REST-style provider (Easypaisa MA + OTC in 1.1; future providers
    # to follow). Universal shape so host apps can branch on
    # payment_mode rather than provider-specific response classes.
    #
    # OTC fills payment_token and expires_at (the customer takes that
    # token to an Easypaisa shop). MA fills transaction_id (the
    # gateway's Ericsson EWP id) and leaves payment_token nil.
    #
    # response_code/response_message are the upstream provider's raw
    # status code and human-readable reason. Compare against
    # success_code for the success predicate -- Easypaisa says "0000",
    # but other providers may say "000" or "OK".
    ChargeResult = Struct.new(
      :provider,            # Symbol e.g. :easy_paisa
      :basket_id,           # String -- the merchant's reference (Easypaisa orderId)
      :transaction_id,      # String or nil (Easypaisa Ericsson EWP id for MA)
      :payment_token,       # String or nil (OTC only)
      :payment_mode,        # Symbol :mobile_account | :otc
      :expires_at,          # Time or nil (OTC only)
      :transacted_at,       # Time or nil
      :amount,              # String -- echo of input amount
      :currency,            # String
      :customer,            # Hash echo of customer info actually sent
      :response_code,       # String e.g. "0000"
      :response_message,    # String e.g. "SUCCESS"
      :success_code,        # String -- provider's success literal
      :raw,                 # Hash -- full provider response
      keyword_init: true
    ) do
      def success?
        response_code == success_code
      end

      def failed?
        !success?
      end

      def otc?
        payment_mode == :otc
      end

      def mobile_account?
        payment_mode == :mobile_account
      end
    end
  end
end
