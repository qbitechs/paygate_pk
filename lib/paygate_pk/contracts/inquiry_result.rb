# frozen_string_literal: true

module PaygatePk
  module Contracts
    # Returned by status-inquiry calls (Easypaisa Inquire Transaction in
    # 1.1; future providers to follow). Captures the canonical
    # transaction status alongside everything the upstream API hands
    # back so the host app can rebuild its mental model of the
    # transaction without making additional calls.
    InquiryResult = Struct.new(
      :provider,                  # Symbol :easy_paisa
      :basket_id,                 # String  Easypaisa orderId
      :account_num,               # String  Merchant EWP account number
      :store_id,                  # String
      :store_name,                # String
      :payment_token,             # String or nil  OTC only
      :transaction_status,        # String  "PAID" | "FAILED" | "PENDING" | "BLOCKED" | "EXPIRED" | "REVERSED"
      :transaction_amount,        # String
      :transaction_date_time,     # String  "dd/MM/yyyy hh:mm a" as Easypaisa sends
      :payment_token_expiry,      # String or nil  OTC only
      :msisdn,                    # String
      :payment_mode,              # String  "MA" | "OTC" | "CC"
      :response_code,             # String  "0000" on a successful lookup
      :response_message,          # String
      :success_code,              # String  provider's success literal
      :raw,                       # Hash    full provider response
      keyword_init: true
    ) do
      def successful_lookup?
        response_code == success_code
      end

      def paid?
        transaction_status == "PAID"
      end

      def failed?
        transaction_status == "FAILED"
      end

      def pending?
        transaction_status == "PENDING"
      end

      def expired?
        transaction_status == "EXPIRED"
      end

      def blocked?
        transaction_status == "BLOCKED"
      end

      def reversed?
        transaction_status == "REVERSED"
      end
    end
  end
end
