# frozen_string_literal: true

require "test_helper"

class TestEasyPaisaInquiry < Minitest::Test
  INQUIRE_URL = "https://easypaystg.easypaisa.com.pk/easypay-service/rest/v4/inquire-transaction"

  def setup
    super
    configure_easypaisa!
  end

  def sample_response(transaction_status: "PAID", code: "0000")
    {
      orderId: "MS5007",
      accountNum: "654123987",
      storeId: 43,
      storeName: "PG Store 1",
      paymentToken: "40931912",
      transactionStatus: transaction_status,
      transactionAmount: 12,
      transactionDateTime: "09/08/2018 10:04 PM",
      paymentTokenExpiryDateTime: "09/07/2019 05:06 PM",
      msisdn: "03458508726",
      paymentMode: "OTC",
      responseCode: code,
      responseDesc: code == "0000" ? "SUCCESS" : "FAIL"
    }
  end

  def test_happy_path_returns_paid_inquiry_result
    expected_body = {
      "orderId" => "MS5007",
      "storeId" => "43",
      "accountNum" => "654123987"
    }

    stub_request(:post, INQUIRE_URL)
      .with(body: expected_body.to_json)
      .to_return(status: 200, body: sample_response.to_json,
                 headers: { "Content-Type" => "application/json" })

    result = PaygatePk::EasyPaisa::Inquiry.fetch(order_id: "MS5007")

    assert_instance_of PaygatePk::Contracts::InquiryResult, result
    assert_equal :easy_paisa, result.provider
    assert_equal "MS5007",    result.basket_id
    assert_equal "PG Store 1", result.store_name
    assert_equal "OTC",       result.payment_mode
    assert_equal "PAID",      result.transaction_status
    assert result.successful_lookup?
    assert result.paid?
    refute result.pending?
  end

  %w[FAILED PENDING BLOCKED EXPIRED REVERSED].each do |status|
    define_method(:"test_predicate_for_#{status.downcase}") do
      stub_request(:post, INQUIRE_URL)
        .to_return(status: 200, body: sample_response(transaction_status: status).to_json,
                   headers: { "Content-Type" => "application/json" })

      result = PaygatePk::EasyPaisa::Inquiry.fetch(order_id: "MS5007")
      assert result.public_send("#{status.downcase}?"),
             "predicate #{status.downcase}? should be true when transactionStatus == #{status}"
    end
  end

  def test_account_num_falls_back_to_config
    PaygatePk.reset_config!
    configure_easypaisa!(account_num: "from-config")

    stub_request(:post, INQUIRE_URL)
      .with(body: hash_including("accountNum" => "from-config"))
      .to_return(status: 200, body: sample_response.to_json,
                 headers: { "Content-Type" => "application/json" })

    PaygatePk::EasyPaisa::Inquiry.fetch(order_id: "MS5007")
  end

  def test_per_call_account_num_overrides_config
    stub_request(:post, INQUIRE_URL)
      .with(body: hash_including("accountNum" => "per-call"))
      .to_return(status: 200, body: sample_response.to_json,
                 headers: { "Content-Type" => "application/json" })

    PaygatePk::EasyPaisa::Inquiry.fetch(order_id: "MS5007", account_num: "per-call")
  end

  def test_missing_args_raises_validation_error
    PaygatePk.reset_config!
    configure_easypaisa!(account_num: nil)

    err = assert_raises(PaygatePk::ValidationError) do
      PaygatePk::EasyPaisa::Inquiry.fetch(order_id: "")
    end
    assert_includes err.details[:missing], :order_id
    assert_includes err.details[:missing], :account_num
  end
end
