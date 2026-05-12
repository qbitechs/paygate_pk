# frozen_string_literal: true

module PaygatePk
  module EasyPaisa
    # Initiate OTC Transaction — issues a paymentToken the customer
    # takes to any Easypaisa shop and pays with cash. The merchant gets
    # paid when Easypaisa reconciles the shop deposit (status moves to
    # PAID; poll via Inquiry.fetch or rely on IPN once configured in
    # the merchant portal).
    #
    # POST {base}/easypay-service/rest/v4/initiate-otc-transaction
    #
    # Usage:
    #
    #   voucher = PaygatePk::EasyPaisa::OTC.create(
    #     order_id:     "lawzo-#{payment.id}",
    #     amount:       1500,
    #     msisdn:       "03001234567",
    #     email:        "client@example.com",
    #     token_expiry: 7.days.from_now
    #   )
    #   voucher.payment_token  # => "40933012" (show this to the customer)
    #   voucher.expires_at     # => Time
    class OTC
      TRANSACTION_TYPE = "OTC"

      def self.create(**kwargs)
        new.create(**kwargs)
      end

      def initialize(config: PaygatePk::EasyPaisa.config, client: nil)
        @config = config
        @client = client
      end

      def create(order_id:, amount:, msisdn:, email:, token_expiry:, optional: {})
        ensure_args!(order_id: order_id, amount: amount,
                     msisdn: msisdn, email: email, token_expiry: token_expiry)

        formatted_expiry = format_expiry(token_expiry)

        body = build_body(order_id: order_id, amount: amount, msisdn: msisdn,
                          email: email, token_expiry: formatted_expiry, optional: optional)

        resp = client.post(Endpoints::INITIATE_OTC_PATH, json: body)
        build_result(order_id: order_id, amount: amount, msisdn: msisdn,
                     email: email, formatted_expiry: formatted_expiry, resp: resp)
      end

      private

      def client
        @client ||= Client.new(config: @config)
      end

      def ensure_args!(order_id:, amount:, msisdn:, email:, token_expiry:)
        missing = []
        missing << :order_id     if Coercions.blank?(order_id)
        missing << :amount       if amount.nil?
        missing << :msisdn       if Coercions.blank?(msisdn)
        missing << :email        if Coercions.blank?(email)
        missing << :token_expiry if Coercions.blank?(token_expiry)
        return if missing.empty?

        raise PaygatePk::ValidationError.new(
          "missing required args: #{missing.join(", ")}",
          details: { missing: missing }
        )
      end

      def format_expiry(value)
        formatted = Coercions.to_easypaisa_timestamp(value)
        validate_future!(formatted)
        formatted
      end

      # Easypaisa returns code "0016" when tokenExpiry is in the past.
      # Surface that as a ValidationError up-front so the caller doesn't
      # waste a round-trip.
      def validate_future!(formatted)
        # Parse back to compare; we trust to_easypaisa_timestamp's shape.
        parsed = DateTime.strptime(formatted, Coercions::EASYPAISA_TIMESTAMP).to_time
        return if parsed > Time.now

        raise PaygatePk::ValidationError.new(
          "token_expiry must be in the future (got #{formatted})",
          details: { token_expiry: formatted }
        )
      end

      def build_body(order_id:, amount:, msisdn:, email:, token_expiry:, optional:)
        body = {
          "orderId" => order_id.to_s,
          "storeId" => @config.store_id.to_s,
          "transactionAmount" => Coercions.to_amount_string(amount),
          "transactionType" => TRANSACTION_TYPE,
          "msisdn" => msisdn.to_s,
          "emailAddress" => email.to_s,
          "tokenExpiry" => token_expiry
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

      def build_result(order_id:, amount:, msisdn:, email:, formatted_expiry:, resp:)
        resp = {} unless resp.is_a?(Hash)
        Contracts::ChargeResult.new(
          provider: :easy_paisa,
          basket_id: order_id.to_s,
          transaction_id: nil,
          payment_token: resp["paymentToken"],
          payment_mode: :otc,
          expires_at: parse_easypaisa_time(resp["paymentTokenExpiryDateTime"]) ||
                             DateTime.strptime(formatted_expiry, Coercions::EASYPAISA_TIMESTAMP).to_time,
          transacted_at: parse_easypaisa_time(resp["transactionDateTime"]),
          amount: Coercions.to_amount_string(amount),
          currency: PaygatePk.config.default_currency,
          customer: { msisdn: msisdn.to_s, email: email.to_s },
          response_code: resp["responseCode"],
          response_message: resp["responseDesc"],
          success_code: client.success_code,
          raw: resp
        )
      end

      def parse_easypaisa_time(value)
        return nil if Coercions.blank?(value)

        DateTime.strptime(value, "%d/%m/%Y %I:%M %p").to_time
      rescue ArgumentError, TypeError
        value
      end
    end
  end
end
