# frozen_string_literal: true

require "test_helper"
require "paygate_pk/providers/pay_fast/webhook"
require "paygate_pk/contracts/webhook_event"

class TestPayFastWebhook < Minitest::Test
  def setup
    configure_payfast!(merchant_id: "MID123", secured_key: "SKEY456")
    @webhook = PaygatePk::Providers::PayFast::Webhook.new
    @basket_id = "BASKET123"
    @err_code = "000"
    @validation_hash = PaygatePk::Util::Signature::Payfast.validation_hash(
      basket_id: @basket_id,
      merchant_secret_key: PaygatePk.config.pay_fast.secured_key,
      merchant_id: PaygatePk.config.pay_fast.merchant_id,
      payfast_err_code: @err_code
    )
    @params = {
      "basket_id" => @basket_id,
      "err_code" => @err_code,
      "validation_hash" => @validation_hash,
      "transaction_id" => "TXN789",
      "order_date" => "2025-10-09",
      "amount" => "1000.00",
      "currency" => "PKR",
      "instrument_token" => "INST123",
      "recurring_txn" => "1",
      "err_msg" => "Approved"
    }
  end

  def test_verify_success
    event = @webhook.verify!(@params)
    assert_instance_of PaygatePk::Contracts::WebhookEvent, event
    assert_equal :payfast, event.provider
    assert_equal @basket_id, event.basket_id
    assert_equal true, event.approved
    assert_equal "INST123", event.instrument_token
    assert_equal true, event.recurring
    assert_equal "Approved", event.message
    assert_equal @params, event.raw
  end

  def test_verify_invalid_signature
    bad_params = @params.merge("validation_hash" => "bad_hash")
    assert_raises(PaygatePk::SignatureError) { @webhook.verify!(bad_params) }
  end

  def test_verify_missing_required_param
    %w[basket_id err_code validation_hash].each do |key|
      params = @params.dup
      params.delete(key)
      assert_raises(PaygatePk::SignatureError) { @webhook.verify!(params) }
    end
  end

  def test_recurring_aliases
    params = @params.dup
    params.delete("recurring_txn")
    params["RECURRING_TXN"] = "1"
    event = @webhook.verify!(params)
    assert_equal true, event.recurring
  end

  def test_instrument_token_alias
    params = @params.dup
    params.delete("instrument_token")
    params["Instrument_token"] = "INST999"
    event = @webhook.verify!(params)
    assert_equal "INST999", event.instrument_token
  end
end
