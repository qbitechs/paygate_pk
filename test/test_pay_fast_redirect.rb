# frozen_string_literal: true

require "test_helper"

class TestPayFastRedirect < Minitest::Test
  GET_ACCESS_TOKEN_URL = "https://example.test/Ecommerce/api/Transaction/GetAccessToken"
  POST_TRANSACTION_URL = "https://example.test/Ecommerce/api/Transaction/PostTransaction"

  def setup
    super
    configure_payfast!(base_url: "https://example.test", merchant_name: "Acme Store")
    stub_token!
  end

  def stub_token!(token = "tok-abc")
    stub_request(:post, GET_ACCESS_TOKEN_URL)
      .to_return(status: 200, body: { "ACCESS_TOKEN" => token }.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  def base_args
    {
      basket_id: "B-1001",
      amount: 1500,
      description: "Order #1001",
      customer: { mobile: "03001234567", email: "buyer@example.com" },
      success_url: "https://app/success",
      failure_url: "https://app/failure"
    }
  end

  def test_build_returns_redirect_request_with_correct_action_url
    redirect = PaygatePk::PayFast::Redirect.build(**base_args)
    assert_equal :pay_fast, redirect.provider
    assert_equal POST_TRANSACTION_URL, redirect.action_url
    assert_equal :post, redirect.http_method
    assert_equal "tok-abc", redirect.token
  end

  def test_mandatory_fields_present
    fields = PaygatePk::PayFast::Redirect.build(**base_args).fields

    assert_equal "M123",                       fields["MERCHANT_ID"]
    assert_equal "Acme Store",                 fields["MERCHANT_NAME"]
    assert_equal "tok-abc",                    fields["TOKEN"]
    assert_equal "00",                         fields["PROCCODE"]
    assert_equal "1500",                       fields["TXNAMT"]
    assert_equal "03001234567",                fields["CUSTOMER_MOBILE_NO"]
    assert_equal "buyer@example.com",          fields["CUSTOMER_EMAIL_ADDRESS"]
    assert_equal "Order #1001",                fields["TXNDESC"]
    assert_equal "https://app/success",        fields["SUCCESS_URL"]
    assert_equal "https://app/failure",        fields["FAILURE_URL"]
    assert_equal "B-1001",                     fields["BASKET_ID"]
    assert_equal "PKR",                        fields["CURRENCY_CODE"]
    assert_equal "ECOMM_PURCHASE",             fields["TRAN_TYPE"]
    assert_match(/\A\d{4}-\d{2}-\d{2}\z/,      fields["ORDER_DATE"])
    refute_empty fields["SIGNATURE"]
    refute_empty fields["VERSION"]
  end

  def test_order_date_accepts_date_and_emits_iso_format
    fields = PaygatePk::PayFast::Redirect.build(**base_args, order_date: Date.new(2026, 5, 12)).fields
    assert_equal "2026-05-12", fields["ORDER_DATE"]
  end

  def test_order_date_strips_time_component
    fields = PaygatePk::PayFast::Redirect.build(
      **base_args, order_date: Time.utc(2026, 5, 12, 10, 30)
    ).fields
    assert_equal "2026-05-12", fields["ORDER_DATE"]
  end

  def test_recurring_renders_as_truthy_string
    fields = PaygatePk::PayFast::Redirect.build(**base_args, recurring: true).fields
    assert_equal "TRUE", fields["RECURRING_TXN"]
  end

  def test_recurring_false_renders_explicitly
    fields = PaygatePk::PayFast::Redirect.build(**base_args, recurring: false).fields
    assert_equal "FALSE", fields["RECURRING_TXN"]
  end

  def test_signature_is_freshly_random_per_call
    a = PaygatePk::PayFast::Redirect.build(**base_args).fields["SIGNATURE"]
    b = PaygatePk::PayFast::Redirect.build(**base_args).fields["SIGNATURE"]
    refute_equal a, b
  end

  def test_store_id_from_config_when_omitted
    PaygatePk.reset_config!
    configure_payfast!(base_url: "https://example.test", store_id: "102-ABC")
    stub_token!
    fields = PaygatePk::PayFast::Redirect.build(**base_args).fields
    assert_equal "102-ABC", fields["STORE_ID"]
  end

  def test_store_id_per_call_overrides_config
    PaygatePk.reset_config!
    configure_payfast!(base_url: "https://example.test", store_id: "from-config")
    stub_token!
    fields = PaygatePk::PayFast::Redirect.build(**base_args, store_id: "per-call").fields
    assert_equal "per-call", fields["STORE_ID"]
  end

  def test_checkout_url_emitted_when_provided
    fields = PaygatePk::PayFast::Redirect.build(
      **base_args, checkout_url: "https://app/ipn"
    ).fields
    assert_equal "https://app/ipn", fields["CHECKOUT_URL"]
  end

  def test_customer_name_propagates_to_optional_field
    args = base_args.merge(customer: base_args[:customer].merge(name: "Talha"))
    fields = PaygatePk::PayFast::Redirect.build(**args).fields
    assert_equal "Talha", fields["CUSTOMER_NAME"]
  end

  def test_items_array_explodes_to_indexed_form_fields
    fields = PaygatePk::PayFast::Redirect.build(
      **base_args,
      items: [
        { sku: "SKU-1", name: "Widget", price: 100, qty: 2 },
        { sku: "SKU-2", name: "Gizmo",  price: 50,  qty: 1 }
      ]
    ).fields

    assert_equal "SKU-1",  fields["ITEMS[0][SKU]"]
    assert_equal "Widget", fields["ITEMS[0][NAME]"]
    assert_equal "100",    fields["ITEMS[0][PRICE]"]
    assert_equal "2",      fields["ITEMS[0][QTY]"]
    assert_equal "SKU-2",  fields["ITEMS[1][SKU]"]
  end

  def test_shipping_block_maps_keys_to_payfast_field_names
    fields = PaygatePk::PayFast::Redirect.build(
      **base_args,
      shipping: {
        name: "Talha", address_1: "House 9", address_2: "St 4",
        state: "Punjab", city: "Lahore", postal_code: "54000",
        method: "Courier"
      }
    ).fields

    assert_equal "Talha",   fields["SHIPPING_CUSTOMER_NAME"]
    assert_equal "House 9", fields["SHIPPING_ADDRESS_1"]
    assert_equal "St 4",    fields["SHIPPING_ADDRESS_2"]
    assert_equal "Punjab",  fields["SHIPPING_STATE_PROVINCE"]
    # Preserves the spec typo SHIPPING_ADDRESS_CITU.
    assert_equal "Lahore",  fields["SHIPPING_ADDRESS_CITU"]
    assert_equal "54000",   fields["SHIPPING_POSTALCODE"]
    assert_equal "Courier", fields["SHIPPING_METHOD"]
  end

  def test_billing_block_uses_billing_field_names
    fields = PaygatePk::PayFast::Redirect.build(
      **base_args,
      billing: { name: "Talha", city: "Lahore", address_1: "House 9" }
    ).fields

    assert_equal "Talha",   fields["BILLING_CUSTOMER_NAME"]
    assert_equal "Lahore",  fields["BILLING_ADDRESS_CITY"]
    assert_equal "House 9", fields["BILLING_ADDRESS_1"]
  end

  def test_extra_fields_passthrough
    fields = PaygatePk::PayFast::Redirect.build(
      **base_args, extra_fields: { "CUSTOM_X" => "value" }
    ).fields
    assert_equal "value", fields["CUSTOM_X"]
  end

  def test_currency_default_falls_back_to_config
    fields = PaygatePk::PayFast::Redirect.build(**base_args).fields
    assert_equal "PKR", fields["CURRENCY_CODE"]
  end

  def test_per_call_currency_overrides_default
    fields = PaygatePk::PayFast::Redirect.build(**base_args, currency: "USD").fields
    assert_equal "USD", fields["CURRENCY_CODE"]
  end

  def test_missing_merchant_name_raises_configuration_error
    PaygatePk.reset_config!
    configure_payfast!(base_url: "https://example.test", merchant_name: nil)
    err = assert_raises(PaygatePk::ConfigurationError) do
      PaygatePk::PayFast::Redirect.build(**base_args)
    end
    assert_match "merchant_name", err.message
  end

  def test_missing_customer_mobile_raises_validation_error
    args = base_args.merge(customer: { email: "x@y.com" })
    err = assert_raises(PaygatePk::ValidationError) do
      PaygatePk::PayFast::Redirect.build(**args)
    end
    assert_match "customer.mobile", err.message
  end

  def test_missing_customer_email_raises_validation_error
    args = base_args.merge(customer: { mobile: "03001234567" })
    err = assert_raises(PaygatePk::ValidationError) do
      PaygatePk::PayFast::Redirect.build(**args)
    end
    assert_match "customer.email", err.message
  end

  def test_missing_success_failure_or_description_raises
    %i[success_url failure_url description].each do |key|
      args = base_args.merge(key => nil)
      err = assert_raises(PaygatePk::ValidationError) do
        PaygatePk::PayFast::Redirect.build(**args)
      end
      assert_match key.to_s, err.message
    end
  end
end
