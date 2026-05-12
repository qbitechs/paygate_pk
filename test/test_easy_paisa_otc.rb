# frozen_string_literal: true

require "test_helper"

class TestEasyPaisaOTC < Minitest::Test
  INITIATE_OTC_URL = "https://easypaystg.easypaisa.com.pk/easypay-service/rest/v4/initiate-otc-transaction"

  def setup
    super
    configure_easypaisa!
  end

  def test_happy_path_posts_required_fields_and_returns_charge_result
    expiry_time = Time.new(2030, 7, 23, 23, 27, 22, "+00:00")

    expected_body = {
      "orderId" => "abc123",
      "storeId" => "43",
      "transactionAmount" => "1.23",
      "transactionType" => "OTC",
      "msisdn" => "03458508726",
      "emailAddress" => "testEmail@gmail.com",
      "tokenExpiry" => expiry_time.strftime("%Y%m%d %H%M%S")
    }

    stub_request(:post, INITIATE_OTC_URL)
      .with(body: expected_body.to_json)
      .to_return(
        status: 200,
        body: {
          orderId: "abc123",
          storeId: 43,
          paymentToken: "40933012",
          transactionDateTime: "11/08/2018 10:41 PM",
          paymentTokenExpiryDateTime: "23/07/2019 11:27 PM",
          responseCode: "0000",
          responseDesc: "SUCCESS"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = PaygatePk::EasyPaisa::OTC.create(
      order_id: "abc123", amount: 1.23,
      msisdn: "03458508726", email: "testEmail@gmail.com",
      token_expiry: expiry_time
    )

    assert_instance_of PaygatePk::Contracts::ChargeResult, result
    assert_equal "40933012",  result.payment_token
    assert_equal :otc,        result.payment_mode
    assert result.otc?
    assert result.success?
    refute_nil result.expires_at
  end

  def test_token_expiry_accepts_a_date
    stub_request(:post, INITIATE_OTC_URL)
      .with(body: hash_including("tokenExpiry" => Date.new(2030, 1, 2).to_time.strftime("%Y%m%d %H%M%S")))
      .to_return(status: 200, body: { responseCode: "0000", paymentToken: "X" }.to_json,
                 headers: { "Content-Type" => "application/json" })

    PaygatePk::EasyPaisa::OTC.create(
      order_id: "d", amount: 1, msisdn: "03001234567",
      email: "x@y.com", token_expiry: Date.new(2030, 1, 2)
    )
  end

  def test_token_expiry_accepts_a_pre_formatted_string
    stub_request(:post, INITIATE_OTC_URL)
      .with(body: hash_including("tokenExpiry" => "20300723 232722"))
      .to_return(status: 200, body: { responseCode: "0000", paymentToken: "X" }.to_json,
                 headers: { "Content-Type" => "application/json" })

    PaygatePk::EasyPaisa::OTC.create(
      order_id: "s", amount: 1, msisdn: "03001234567",
      email: "x@y.com", token_expiry: "20300723 232722"
    )
  end

  def test_past_token_expiry_raises_validation_error
    err = assert_raises(PaygatePk::ValidationError) do
      PaygatePk::EasyPaisa::OTC.create(
        order_id: "p", amount: 1, msisdn: "03001234567", email: "x@y.com",
        token_expiry: Time.new(2000, 1, 1)
      )
    end
    assert_match "token_expiry", err.message
    assert_match "future", err.message
  end

  def test_missing_args_raises_validation_error
    err = assert_raises(PaygatePk::ValidationError) do
      PaygatePk::EasyPaisa::OTC.create(
        order_id: "", amount: nil, msisdn: "", email: "", token_expiry: nil
      )
    end
    %i[order_id amount msisdn email token_expiry].each do |k|
      assert_includes err.details[:missing], k
    end
  end

  def test_non_0000_response_surfaces_failed_voucher
    stub_request(:post, INITIATE_OTC_URL).to_return(
      status: 200,
      body: { responseCode: "0008", responseDesc: "PAYMENT METHOD NOT ENABLED" }.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    result = PaygatePk::EasyPaisa::OTC.create(
      order_id: "x", amount: 1, msisdn: "03001234567", email: "x@y.com",
      token_expiry: Time.now + 86_400
    )

    refute result.success?
    assert_nil result.payment_token
    assert_equal "0008", result.response_code
  end
end
