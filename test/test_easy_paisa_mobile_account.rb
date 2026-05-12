# frozen_string_literal: true

require "test_helper"

class TestEasyPaisaMobileAccount < Minitest::Test
  INITIATE_MA_URL = "https://easypaystg.easypaisa.com.pk/easypay-service/rest/v4/initiate-ma-transaction"

  def setup
    super
    configure_easypaisa!
  end

  def expected_credentials_header
    Base64.strict_encode64("EP-USER:EP-PASS")
  end

  def test_happy_path_posts_required_fields_and_returns_charge_result
    expected_body = {
      "orderId" => "order-001",
      "storeId" => "43",
      "transactionAmount" => "1500",
      "transactionType" => "MA",
      "mobileAccountNo" => "03001234567",
      "emailAddress" => "client@example.com"
    }

    stub_request(:post, INITIATE_MA_URL)
      .with(
        body: expected_body.to_json,
        headers: {
          "Content-Type" => "application/json",
          "Credentials" => expected_credentials_header
        }
      )
      .to_return(
        status: 200,
        body: {
          orderId: "order-001",
          storeId: 43,
          transactionId: "253184",
          transactionDateTime: "11/08/2018 11:30 PM",
          responseCode: "0000",
          responseDesc: "SUCCESS"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = PaygatePk::EasyPaisa::MobileAccount.charge(
      order_id: "order-001",
      amount: 1500,
      mobile_account_no: "03001234567",
      email: "client@example.com"
    )

    assert_instance_of PaygatePk::Contracts::ChargeResult, result
    assert_equal :easy_paisa,        result.provider
    assert_equal "order-001",        result.basket_id
    assert_equal "253184",           result.transaction_id
    assert_equal :mobile_account,    result.payment_mode
    assert_nil result.payment_token
    assert_equal "1500",             result.amount
    assert_equal "PKR",              result.currency
    assert_equal "0000",             result.response_code
    assert_equal "SUCCESS",          result.response_message
    assert result.success?
    assert result.mobile_account?
    refute result.otc?
  end

  def test_optional_keys_propagate_to_body
    stub = stub_request(:post, INITIATE_MA_URL)
           .with(body: hash_including(
             "optional1" => "tenant-42",
             "optional3" => "promo-xyz"
           ))
           .to_return(status: 200, body: { responseCode: "0000", responseDesc: "OK" }.to_json,
                      headers: { "Content-Type" => "application/json" })

    PaygatePk::EasyPaisa::MobileAccount.charge(
      order_id: "order-002", amount: 100,
      mobile_account_no: "03001234567", email: "x@y.com",
      optional: { "1" => "tenant-42", 2 => nil, "3" => "promo-xyz", "6" => "out-of-range" }
    )

    assert_requested stub
  end

  def test_non_0000_response_surfaces_as_failed_charge_result_not_an_exception
    stub_request(:post, INITIATE_MA_URL).to_return(
      status: 200,
      body: { responseCode: "0013", responseDesc: "LOW BALANCE" }.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    result = PaygatePk::EasyPaisa::MobileAccount.charge(
      order_id: "order-003", amount: 100,
      mobile_account_no: "03001234567", email: "x@y.com"
    )

    refute result.success?
    assert result.failed?
    assert_equal "0013", result.response_code
    assert_equal "LOW BALANCE", result.response_message
  end

  def test_missing_args_raises_validation_error_with_details
    err = assert_raises(PaygatePk::ValidationError) do
      PaygatePk::EasyPaisa::MobileAccount.charge(
        order_id: "", amount: nil, mobile_account_no: "", email: ""
      )
    end
    %i[order_id amount mobile_account_no email].each do |k|
      assert_includes err.details[:missing], k
    end
  end

  def test_missing_config_raises
    PaygatePk.reset_config!
    PaygatePk.configure do |c|
      c.easy_paisa.environment = :sandbox
      # intentionally omit username/password/store_id
    end

    err = assert_raises(PaygatePk::ConfigurationError) do
      PaygatePk::EasyPaisa::MobileAccount.charge(
        order_id: "x", amount: 1, mobile_account_no: "03001234567", email: "x@y.com"
      )
    end
    assert_match "username", err.message
    assert_match "password", err.message
    assert_match "store_id", err.message
  end
end
