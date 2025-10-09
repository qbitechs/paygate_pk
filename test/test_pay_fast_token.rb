# frozen_string_literal: true

require "test_helper"
require "paygate_pk/providers/pay_fast/tokenization/token"
require "paygate_pk/contracts/bearer_token"
require "webmock/minitest"

class TestPayFastToken < Minitest::Test
  def setup
    configure_payfast!(merchant_id: "MID123", secured_key: "SKEY456", api_base_url: "https://api.example.com")
    @token = PaygatePk::Providers::PayFast::Tokenization::Token.new(config: PaygatePk.config.pay_fast)
    @http_client = Minitest::Mock.new
    @token.stub(:http, @http_client) do
      # nothing, just setup stub
    end
  end

  # rubocop:disable Metrics/AbcSize
  def test_get_success
    stub_request(:post, "https://api.example.com/api/token")
      .with(
        body: { "merchant_id" => "MID123", "secured_key" => "SKEY456", "grant_type" => "client_credentials" },
        headers: { "Accept" => "application/json" }
      )
      .to_return(
        status: 200,
        body: {
          token: "ACCESS123",
          refresh_token: "REFRESH456",
          expiry: 3600,
          code: "200",
          message: "OK"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @token.get(grant_type: "client_credentials")
    assert_instance_of PaygatePk::Contracts::BearerToken, result
    assert_equal "ACCESS123", result.access_token
    assert_equal "REFRESH456", result.refresh_token
    assert_equal 3600, result.expiry
    assert_equal "200", result.code
    assert_equal "OK", result.message
    assert_equal JSON.parse({
      token: "ACCESS123",
      refresh_token: "REFRESH456",
      expiry: 3600,
      code: "200",
      message: "OK"
    }.to_json), result.raw
  end
  # rubocop:enable Metrics/AbcSize

  def test_body_with_options
    options = {
      customer_ip: "1.2.3.4",
      reserved1: "foo",
      reserved2: "bar",
      reserved3: "baz",
      api_version: "v2"
    }
    body = @token.send(:body, "MID123", "SKEY456", "client_credentials", options)
    assert_equal "1.2.3.4", body["customer_ip"]
    assert_equal "foo", body["reserved_1"]
    assert_equal "bar", body["reserved_2"]
    assert_equal "baz", body["reserved_3"]
    assert_equal "v2", body["api_version"]
  end
end
