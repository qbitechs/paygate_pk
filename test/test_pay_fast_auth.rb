# frozen_string_literal: true

require "test_helper"

class TestPayFastAuth < Minitest::Test
  GET_ACCESS_TOKEN_URL = "https://example.test/Ecommerce/api/Transaction/GetAccessToken"

  def test_get_access_token_success
    configure_payfast!(base_url: "https://example.test")
    expected_form = {
      "MERCHANT_ID"   => "M123",
      "SECURED_KEY"   => "SKEY",
      "BASKET_ID"     => "B-1",
      "TXNAMT"        => "1500",
      "CURRENCY_CODE" => "PKR"
    }

    stub_request(:post, GET_ACCESS_TOKEN_URL)
      .with(body: URI.encode_www_form(expected_form))
      .to_return(status: 200, body: '{"ACCESS_TOKEN":"t-abc"}',
                 headers: { "Content-Type" => "application/json" })

    token = PaygatePk::PayFast::Auth.call(basket_id: "B-1", amount: 1500)
    assert_equal "t-abc", token.value
    assert_equal "t-abc", token.token # alias
    assert_kind_of Hash, token.raw
  end

  def test_missing_config_raises
    PaygatePk.configure do |c|
      c.pay_fast.base_url = "https://example.test"
      # intentionally omit merchant_id / secured_key
    end

    err = assert_raises(PaygatePk::ConfigurationError) do
      PaygatePk::PayFast::Auth.call(basket_id: "B-1", amount: 100)
    end
    assert_match "merchant_id", err.message
    assert_match "secured_key", err.message
  end

  def test_missing_args_raises_validation_error_with_details
    configure_payfast!(base_url: "https://example.test")
    err = assert_raises(PaygatePk::ValidationError) do
      PaygatePk::PayFast::Auth.call(basket_id: "", amount: nil)
    end
    assert_match "basket_id", err.message
    assert_match "amount", err.message
    assert_includes err.details[:missing], :basket_id
    assert_includes err.details[:missing], :amount
  end

  def test_missing_token_in_response_raises_auth_error
    configure_payfast!(base_url: "https://example.test")
    stub_request(:post, GET_ACCESS_TOKEN_URL)
      .to_return(status: 200, body: '{"status":"ok"}',
                 headers: { "Content-Type" => "application/json" })

    err = assert_raises(PaygatePk::AuthError) do
      PaygatePk::PayFast::Auth.call(basket_id: "B-1", amount: 100)
    end
    assert_match "ACCESS_TOKEN", err.message
  end

  def test_accepts_lowercase_access_token_key
    configure_payfast!(base_url: "https://example.test")
    stub_request(:post, GET_ACCESS_TOKEN_URL)
      .to_return(status: 200, body: '{"access_token":"t-low"}',
                 headers: { "Content-Type" => "application/json" })

    token = PaygatePk::PayFast::Auth.call(basket_id: "B-1", amount: 100)
    assert_equal "t-low", token.value
  end
end
