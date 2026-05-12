# frozen_string_literal: true

require "date"
require "securerandom"

module PaygatePk
  module PayFast
    # Builds the redirect form that the customer's browser submits to
    # PayFast's hosted checkout page.
    #
    # Flow (Merchant Integration Guide v2.3 §3.2):
    #   1. Fetch ACCESS_TOKEN server-to-server (delegated to Auth)
    #   2. Assemble all the PostTransaction form fields (mandatory +
    #      optional), with PayFast's UPPER_SNAKE_CASE naming
    #   3. Return a Contracts::RedirectRequest the host app renders
    #      as an auto-submitting <form>
    #
    # Usage:
    #
    #   redirect = PaygatePk::PayFast::Redirect.build(
    #     basket_id:    "sp-#{payment.id}",
    #     amount:       1500,
    #     description:  "Subscription",
    #     customer:     { mobile: "03001234567", email: "buyer@x.com", name: "Talha" },
    #     success_url:  success_url,
    #     failure_url:  failure_url,
    #     checkout_url: webhooks_pay_fast_url,  # optional, IPN backend ping
    #     recurring:    false
    #   )
    class Redirect
      # Address-block field mapping. Preserves the SHIPPING_ADDRESS_CITU
      # typo from the PayFast spec — we mirror what the gateway accepts,
      # not what looks correct.
      SHIPPING_FIELDS = {
        name: "SHIPPING_CUSTOMER_NAME",
        address_1: "SHIPPING_ADDRESS_1",
        address_2: "SHIPPING_ADDRESS_2",
        state: "SHIPPING_STATE_PROVINCE",
        city: "SHIPPING_ADDRESS_CITU",
        postal_code: "SHIPPING_POSTALCODE",
        method: "SHIPPING_METHOD"
      }.freeze

      BILLING_FIELDS = {
        name: "BILLING_CUSTOMER_NAME",
        city: "BILLING_ADDRESS_CITY",
        address_1: "BILLING_ADDRESS_1",
        address_2: "BILLING_ADDRESS_2",
        state: "BILLING_STATE_PROVINCE",
        postal_code: "BILLING_POSTALCODE"
      }.freeze

      def self.build(**kwargs)
        new.build(**kwargs)
      end

      def initialize(config: PaygatePk::PayFast.config, auth: nil)
        @config = config
        @auth   = auth
      end

      def build(basket_id:, amount:, customer:, success_url:, failure_url:, description:,
                currency: nil, order_date: nil, checkout_url: nil, store_id: nil,
                items: [], recurring: false, tran_type: nil, processing_type: nil,
                instrument_token: nil, shipping: nil, billing: nil, country: nil,
                customer_ip: nil, merchant_customer_id: nil, merchant_user_agent: nil,
                transaction_instrument: nil, extra_fields: {})
        currency ||= PaygatePk.config.default_currency
        order_date_str = Coercions.to_iso_date(order_date) || Date.today.strftime("%Y-%m-%d")

        ensure_config!
        ensure_args!(basket_id: basket_id, amount: amount, customer: customer,
                     success_url: success_url, failure_url: failure_url, description: description)

        token = auth.call(basket_id: basket_id, amount: amount, currency: currency)

        fields = build_fields(
          token: token.value,
          basket_id: basket_id,
          amount: amount,
          currency: currency,
          customer: customer,
          success_url: success_url,
          failure_url: failure_url,
          checkout_url: checkout_url,
          description: description,
          order_date_str: order_date_str,
          store_id: store_id,
          items: items,
          recurring: recurring,
          tran_type: tran_type,
          processing_type: processing_type,
          instrument_token: instrument_token,
          transaction_instrument: transaction_instrument,
          shipping: shipping,
          billing: billing,
          country: country,
          customer_ip: customer_ip,
          merchant_customer_id: merchant_customer_id,
          merchant_user_agent: merchant_user_agent,
          extra_fields: extra_fields
        )

        Contracts::RedirectRequest.new(
          provider: :pay_fast,
          action_url: Endpoints.post_transaction_url(@config.resolved_base_url),
          http_method: :post,
          fields: fields,
          basket_id: basket_id.to_s,
          amount: Coercions.to_amount_string(amount),
          token: token.value,
          raw: token.raw
        )
      end

      private

      def auth
        @auth ||= Auth.new(config: @config)
      end

      def ensure_config!
        missing = []
        missing << :merchant_id   if Coercions.blank?(@config.merchant_id)
        missing << :secured_key   if Coercions.blank?(@config.secured_key)
        missing << :merchant_name if Coercions.blank?(@config.merchant_name)
        return if missing.empty?

        raise PaygatePk::ConfigurationError, "PayFast config missing: #{missing.join(", ")}"
      end

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def ensure_args!(basket_id:, amount:, customer:, success_url:, failure_url:, description:)
        missing = []
        missing << :basket_id   if Coercions.blank?(basket_id)
        missing << :amount      if amount.nil?
        missing << :success_url if Coercions.blank?(success_url)
        missing << :failure_url if Coercions.blank?(failure_url)
        missing << :description if Coercions.blank?(description)
        missing << "customer.mobile" if !customer.is_a?(Hash) || Coercions.blank?(customer[:mobile])
        missing << "customer.email" if !customer.is_a?(Hash) || Coercions.blank?(customer[:email])
        return if missing.empty?

        raise PaygatePk::ValidationError.new(
          "missing required args: #{missing.join(", ")}",
          details: { missing: missing }
        )
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      def build_fields(**opts)
        fields = {}
        add_mandatory_fields!(fields, opts)
        add_optional_simple_fields!(fields, opts)
        add_address_fields!(fields, "SHIPPING", opts[:shipping]) if opts[:shipping]
        add_address_fields!(fields, "BILLING",  opts[:billing])  if opts[:billing]
        add_items_fields!(fields, opts[:items]) if opts[:items].is_a?(Array) && !opts[:items].empty?
        add_extra_fields!(fields, opts[:extra_fields])
        fields
      end

      # rubocop:disable Metrics/AbcSize
      def add_mandatory_fields!(fields, opts)
        fields["MERCHANT_ID"]            = @config.merchant_id
        fields["MERCHANT_NAME"]          = @config.merchant_name
        fields["TOKEN"]                  = opts[:token]
        fields["PROCCODE"]               = "00"
        fields["TXNAMT"]                 = Coercions.to_amount_string(opts[:amount])
        fields["CUSTOMER_MOBILE_NO"]     = opts[:customer][:mobile].to_s
        fields["CUSTOMER_EMAIL_ADDRESS"] = opts[:customer][:email].to_s
        # SIGNATURE and VERSION are documented as "A random string value"
        # in Merchant Integration Guide v2.3 §3.2 — they are not crypto
        # signatures. We generate a fresh random per request.
        fields["SIGNATURE"]              = SecureRandom.hex(16)
        fields["VERSION"]                = @config.version_string || "paygate_pk/#{PaygatePk::VERSION}"
        fields["TXNDESC"]                = opts[:description]
        fields["SUCCESS_URL"]            = opts[:success_url]
        fields["FAILURE_URL"]            = opts[:failure_url]
        fields["BASKET_ID"]              = opts[:basket_id].to_s
        fields["ORDER_DATE"]             = opts[:order_date_str]
        fields["CURRENCY_CODE"]          = opts[:currency]
        fields["TRAN_TYPE"]              = opts[:tran_type] || @config.tran_type
      end
      # rubocop:enable Metrics/AbcSize

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def add_optional_simple_fields!(fields, opts)
        fields["CHECKOUT_URL"]           = opts[:checkout_url] if opts[:checkout_url]
        store_id                         = opts[:store_id] || @config.store_id
        fields["STORE_ID"]               = store_id if Coercions.present?(store_id)
        fields["RECURRING_TXN"]          = opts[:recurring] ? "TRUE" : "FALSE"
        fields["CUSTOMER_NAME"]          = opts[:customer][:name].to_s          if opts[:customer][:name]
        fields["CUSTOMER_IPADDRESS"]     = opts[:customer_ip]                   if opts[:customer_ip]
        fields["MERCHANT_CUSTOMER_ID"]   = opts[:merchant_customer_id]          if opts[:merchant_customer_id]
        fields["MERCHANT_USERAGENT"]     = opts[:merchant_user_agent]           if opts[:merchant_user_agent]
        fields["COUNTRY"]                = opts[:country]                       if opts[:country]
        fields["PROCESSING_TYPE"]        = opts[:processing_type]               if opts[:processing_type]
        fields["INSTRUMENT_TOKEN"]       = opts[:instrument_token]              if opts[:instrument_token]
        fields["Transaction_Instrument"] = opts[:transaction_instrument].to_s   if opts[:transaction_instrument]
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      def add_address_fields!(fields, prefix, hash)
        map = prefix == "SHIPPING" ? SHIPPING_FIELDS : BILLING_FIELDS
        map.each do |key, payfast_name|
          v = hash[key]
          fields[payfast_name] = v.to_s if Coercions.present?(v)
        end
      end

      def add_items_fields!(fields, items)
        items.each_with_index do |item, i|
          fields["ITEMS[#{i}][SKU]"]   = item[:sku].to_s                       if item[:sku]
          fields["ITEMS[#{i}][NAME]"]  = item[:name].to_s                      if item[:name]
          fields["ITEMS[#{i}][PRICE]"] = Coercions.to_amount_string(item[:price]) if item[:price]
          fields["ITEMS[#{i}][QTY]"]   = item[:qty].to_s if item[:qty]
        end
      end

      def add_extra_fields!(fields, extras)
        return unless extras.is_a?(Hash)

        extras.each { |k, v| fields[k.to_s] = v.to_s }
      end
    end
  end
end
