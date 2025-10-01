# frozen_string_literal: true

require "test_helper"

class TestPayFastAuth < Minitest::Test
  def setup
    super
    configure_payfast!(base_url: "https://example.test")
  end

  def test_get_access_token_success
    # Expect the exact form body fields your Auth#payload builds:
    expected_form = {
      "MERCHANT_ID" => "M123",
      "SECURED_KEY" => "SKEY",
      "BASKET_ID" => "B-1",
      "TXNAMT" => "1500",
      "CURRENCY_CODE" => "PKR"
    }

    stub_request(:post, "https://example.test/Ecommerce/api/Transaction/GetAccessToken")
      .with(body: URI.encode_www_form(expected_form))
      .to_return(status: 200, body: '{"ACCESS_TOKEN":"t-abc"}', headers: { "Content-Type" => "application/json" })

    auth = PaygatePk::Providers::PayFast::Auth.new(config: PaygatePk.config.pay_fast)

    # NOTE: this call assumes you've added the missing currency arg default (see patch below)
    token_obj = auth.get_access_token(basket_id: "B-1", amount: 1500)
    assert_equal "t-abc", token_obj.token
    assert_kind_of Hash, token_obj.raw
  end

  def test_get_access_token_missing_config
    reset_paygate_config!
    PaygatePk.configure do |c|
      c.pay_fast.base_url = "https://example.test"
      # intentionally omit merchant_id / secured_key
    end

    auth = PaygatePk::Providers::PayFast::Auth.new(config: PaygatePk.config.pay_fast)
    err = assert_raises(PaygatePk::ConfigurationError) do
      auth.get_access_token(basket_id: "B-1", amount: 100)
    end
    assert_match "merchant_id", err.message
  end

  def test_get_access_token_missing_args
    configure_payfast!(base_url: "https://example.test")
    auth = PaygatePk::Providers::PayFast::Auth.new(config: PaygatePk.config.pay_fast)

    err = assert_raises(PaygatePk::ValidationError) do
      auth.get_access_token(basket_id: "", amount: nil) # currency default is used, but basket/amount invalid
    end
    assert_match "basket_id", err.message
    assert_match "amount", err.message
  end

  def test_missing_token_in_response_raises
    configure_payfast!(base_url: "https://example.test")
    stub_request(:post, "https://example.test/Ecommerce/api/Transaction/GetAccessToken")
      .to_return(status: 200, body: '{"status":"ok"}', headers: { "Content-Type" => "application/json" })

    auth = PaygatePk::Providers::PayFast::Auth.new(config: PaygatePk.config.pay_fast)
    err = assert_raises(PaygatePk::AuthError) do
      auth.get_access_token(basket_id: "B-1", amount: 100)
    end
    assert_match "ACCESS_TOKEN", err.message
  end
end
