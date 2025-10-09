# frozen_string_literal: true

require "test_helper"
require "paygate_pk/providers/pay_fast/tokenization/instrument"
require "paygate_pk/contracts/instrument"
require "webmock/minitest"

class TestPayFastInstrument < Minitest::Test
  def setup
    configure_payfast!(merchant_id: "MID123", secured_key: "SKEY456", api_base_url: "https://api.example.com")
    @instrument = PaygatePk::Providers::PayFast::Tokenization::Instrument.new(config: PaygatePk.config.pay_fast)
    @token = "ACCESS123"
    @user_id = "USER456"
    @mobile_number = "03001234567"
    @endpoint = "/api/user/instruments"
    @url = "https://api.example.com#{@endpoint}"
  end

  # rubocop:disable Metrics/AbcSize
  def test_list_success
    stub_request(:get, "https://api.example.com/api/user/instruments")
      .with(
        query: {
          "merchant_user_id" => @user_id,
          "user_mobile_number" => @mobile_number
        },
        headers: {
          "Accept" => "application/json",
          "Authorization" => "Bearer #{@token}"
        }
      )
      .to_return(
        status: 200,
        body: [
          {
            "instrument_token" => "INST1",
            "account_type" => "bank",
            "description" => "Bank Account",
            "instrument_alias" => "My Bank"
          },
          {
            "instrument_token" => "INST2",
            "account_type" => "card",
            "description" => "Credit Card",
            "instrument_alias" => "Visa"
          }
        ].to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @instrument.list(token: @token, user_id: @user_id, mobile_number: @mobile_number)
    assert_equal 2, result.size
    assert_instance_of PaygatePk::Contracts::Instrument, result.first
    assert_equal "INST1", result.first.instrument_token
    assert_equal "bank", result.first.account_type
    assert_equal "My Bank", result.first.instrument_alias
    assert_equal "INST2", result.last.instrument_token
    assert_equal "card", result.last.account_type
    assert_equal "Visa", result.last.instrument_alias
  end
  # rubocop:enable Metrics/AbcSize

  def test_list_missing_required_args
    assert_raises(PaygatePk::ValidationError) do
      @instrument.list(token: nil, user_id: @user_id, mobile_number: @mobile_number)
    end
    assert_raises(PaygatePk::ValidationError) do
      @instrument.list(token: @token, user_id: nil, mobile_number: @mobile_number)
    end
    assert_raises(PaygatePk::ValidationError) do
      @instrument.list(token: @token, user_id: @user_id, mobile_number: nil)
    end
  end

  def test_body_with_options
    options = {
      customer_ip: "1.2.3.4",
      reserved_1: "foo",
      reserved_2: "bar",
      reserved_3: "baz",
      api_version: "v2"
    }
    body = @instrument.send(:body, @user_id, @mobile_number, options)
    assert_equal "1.2.3.4", body["customer_ip"]
    assert_equal "foo", body["reserved_1"]
    assert_equal "bar", body["reserved_2"]
    assert_equal "baz", body["reserved_3"]
    assert_equal "v2", body["api_version"]
  end
end
