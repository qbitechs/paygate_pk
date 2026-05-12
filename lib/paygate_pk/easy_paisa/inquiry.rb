# frozen_string_literal: true

module PaygatePk
  module EasyPaisa
    # Inquire Transaction Status — given an orderId we previously
    # submitted (and the merchant EWP account number), Easypaisa
    # returns the current state. Use this to drive your own state
    # machine for OTC payments (where success arrives asynchronously
    # when the customer pays at a shop) or as a poor-man's IPN
    # replacement until the IPN spec is wired.
    #
    # POST {base}/easypay-service/rest/v4/inquire-transaction
    #
    # Usage:
    #
    #   status = PaygatePk::EasyPaisa::Inquiry.fetch(
    #     order_id:    "lawzo-#{payment.id}",
    #     account_num: PaygatePk.config.easy_paisa.account_num
    #   )
    #   status.paid?     # transactionStatus == "PAID"
    #   status.pending?  # transactionStatus == "PENDING"
    class Inquiry
      def self.fetch(**kwargs)
        new.fetch(**kwargs)
      end

      def initialize(config: PaygatePk::EasyPaisa.config, client: nil)
        @config = config
        @client = client
      end

      def fetch(order_id:, account_num: nil)
        account_num ||= @config.account_num
        ensure_args!(order_id: order_id, account_num: account_num)

        body = {
          "orderId"    => order_id.to_s,
          "storeId"    => @config.store_id.to_s,
          "accountNum" => account_num.to_s
        }

        resp = client.post(Endpoints::INQUIRE_PATH, json: body)
        build_result(order_id, account_num, resp)
      end

      private

      def client
        @client ||= Client.new(config: @config)
      end

      def ensure_args!(order_id:, account_num:)
        missing = []
        missing << :order_id    if Coercions.blank?(order_id)
        missing << :account_num if Coercions.blank?(account_num)
        return if missing.empty?

        raise PaygatePk::ValidationError.new(
          "missing required args: #{missing.join(", ")}",
          details: { missing: missing }
        )
      end

      def build_result(order_id, account_num, resp)
        resp = {} unless resp.is_a?(Hash)
        Contracts::InquiryResult.new(
          provider:               :easy_paisa,
          basket_id:              order_id.to_s,
          account_num:            account_num.to_s,
          store_id:               resp["storeId"]&.to_s,
          store_name:             resp["storeName"],
          payment_token:          resp["paymentToken"],
          transaction_status:     resp["transactionStatus"],
          transaction_amount:     resp["transactionAmount"]&.to_s,
          transaction_date_time:  resp["transactionDateTime"],
          payment_token_expiry:   resp["paymentTokenExpiryDateTime"],
          msisdn:                 resp["msisdn"],
          payment_mode:           resp["paymentMode"],
          response_code:          resp["responseCode"],
          response_message:       resp["responseDesc"],
          success_code:           client.success_code,
          raw:                    resp
        )
      end
    end
  end
end
