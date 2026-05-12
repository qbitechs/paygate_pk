# frozen_string_literal: true

module PaygatePk
  module EasyPaisa
    # Initiate MA Transaction — pushes an OTP confirmation to the
    # customer's Easypaisa wallet so they can authorise payment without
    # leaving the merchant site.
    #
    # POST {base}/easypay-service/rest/v4/initiate-ma-transaction
    #
    # Usage:
    #
    #   result = PaygatePk::EasyPaisa::MobileAccount.charge(
    #     order_id:          "lawzo-#{payment.id}",
    #     amount:            1500,
    #     mobile_account_no: "03001234567",
    #     email:             "client@example.com"
    #   )
    #   result.success?       # => true if responseCode == "0000"
    #   result.transaction_id # => Ericsson EWP ID (string)
    class MobileAccount
      TRANSACTION_TYPE = "MA"

      def self.charge(**kwargs)
        new.charge(**kwargs)
      end

      def initialize(config: PaygatePk::EasyPaisa.config, client: nil)
        @config = config
        @client = client
      end

      def charge(order_id:, amount:, mobile_account_no:, email:, optional: {})
        ensure_args!(order_id: order_id, amount: amount,
                     mobile_account_no: mobile_account_no, email: email)

        body = build_body(order_id: order_id, amount: amount,
                          mobile_account_no: mobile_account_no, email: email,
                          optional: optional)

        resp = client.post(Endpoints::INITIATE_MA_PATH, json: body)
        build_result(order_id: order_id, amount: amount,
                     mobile_account_no: mobile_account_no, email: email,
                     resp: resp)
      end

      private

      def client
        @client ||= Client.new(config: @config)
      end

      def ensure_args!(order_id:, amount:, mobile_account_no:, email:)
        missing = []
        missing << :order_id          if Coercions.blank?(order_id)
        missing << :amount            if amount.nil?
        missing << :mobile_account_no if Coercions.blank?(mobile_account_no)
        missing << :email             if Coercions.blank?(email)
        return if missing.empty?

        raise PaygatePk::ValidationError.new(
          "missing required args: #{missing.join(", ")}",
          details: { missing: missing }
        )
      end

      def build_body(order_id:, amount:, mobile_account_no:, email:, optional:)
        body = {
          "orderId" => order_id.to_s,
          "storeId" => @config.store_id.to_s,
          "transactionAmount" => Coercions.to_amount_string(amount),
          "transactionType" => TRANSACTION_TYPE,
          "mobileAccountNo" => mobile_account_no.to_s,
          "emailAddress" => email.to_s
        }
        add_optionals!(body, optional)
        body
      end

      def add_optionals!(body, optional)
        return unless optional.is_a?(Hash)

        optional.each do |key, value|
          next if Coercions.blank?(value)
          next unless ("1".."5").cover?(key.to_s)

          body["optional#{key}"] = value.to_s
        end
      end

      def build_result(order_id:, amount:, mobile_account_no:, email:, resp:)
        resp = {} unless resp.is_a?(Hash)
        Contracts::ChargeResult.new(
          provider: :easy_paisa,
          basket_id: order_id.to_s,
          transaction_id: resp["transactionId"],
          payment_token: nil,
          payment_mode: :mobile_account,
          expires_at: nil,
          transacted_at: parse_easypaisa_time(resp["transactionDateTime"]),
          amount: Coercions.to_amount_string(amount),
          currency: PaygatePk.config.default_currency,
          customer: { mobile_account_no: mobile_account_no.to_s, email: email.to_s },
          response_code: resp["responseCode"],
          response_message: resp["responseDesc"],
          success_code: client.success_code,
          raw: resp
        )
      end

      # Easypaisa hands back "dd/MM/yyyy hh:mm a" (e.g. "11/08/2018 11:30 PM").
      # Best-effort parse -- returns the raw string if it's in some
      # unexpected shape rather than blowing up the call site.
      def parse_easypaisa_time(value)
        return nil if Coercions.blank?(value)

        DateTime.strptime(value, "%d/%m/%Y %I:%M %p").to_time
      rescue ArgumentError, TypeError
        value
      end
    end
  end
end
