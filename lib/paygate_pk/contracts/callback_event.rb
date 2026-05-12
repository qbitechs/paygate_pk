# frozen_string_literal: true

module PaygatePk
  module Contracts
    # Normalised IPN / browser-return notification.
    #
    # Built by PaygatePk::PayFast::Callback.verify!(params). Will also
    # be returned by Easypaisa's callback handler in 1.1, with the same
    # fields populated where applicable. This is the gem's universal
    # contract for "the gateway told us something about a transaction".
    #
    # Numeric-looking fields (amount, merchant_amount, discounted_amount)
    # are surfaced as Strings — exactly as PayFast sent them. The host
    # app converts to BigDecimal/Money on its side.
    CallbackEvent = Struct.new(
      :provider,           # Symbol e.g. :pay_fast
      :transaction_id,     # String or nil
      :basket_id,          # String
      :order_date,         # String "YYYY-MM-DD"
      :approved,           # Boolean — true if code == provider's success code
      :code,               # String — err_code or responseCode
      :message,            # String — err_msg or responseDesc
      :amount,             # String — transaction_amount
      :merchant_amount,    # String
      :discounted_amount,  # String
      :currency,           # String "PKR" etc.
      :payment_method,     # String — PaymentName ("account", "card", "wallet")
      :instrument_token,   # String or nil
      :recurring,          # Boolean
      :raw,                # Hash — original params, unmodified
      keyword_init: true
    ) do
      def approved?
        !!approved
      end
    end
  end
end
