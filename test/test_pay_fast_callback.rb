# frozen_string_literal: true

require "test_helper"

class TestPayFastCallback < Minitest::Test
  def setup
    super
    configure_payfast!(merchant_id: "MID123", secured_key: "SKEY456")
    @basket_id  = "BASKET123"
    @err_code   = "000"
    @validation = PaygatePk::Util::Signature::PayFast.validation_hash(
      basket_id: @basket_id, merchant_secret_key: "SKEY456",
      merchant_id: "MID123", payfast_err_code: @err_code
    )
    @params = {
      "basket_id" => @basket_id,
      "err_code" => @err_code,
      "validation_hash" => @validation,
      "transaction_id" => "TXN789",
      "order_date" => "2026-05-12",
      "transaction_amount" => "1000.00",
      "merchant_amount" => "1000.00",
      "discounted_amount" => "0.00",
      "transaction_currency" => "PKR",
      "Instrument_token" => "INST123",
      "Recurring_txn" => "1",
      "PaymentName" => "card",
      "err_msg" => "Approved"
    }
  end

  def test_verify_success_returns_event
    event = PaygatePk::PayFast::Callback.verify!(@params)
    assert_instance_of PaygatePk::Contracts::CallbackEvent, event
    assert_equal :pay_fast, event.provider
    assert_equal @basket_id, event.basket_id
    assert event.approved?
    assert_equal "000", event.code
    assert_equal "1000.00", event.amount
    assert_equal "1000.00", event.merchant_amount
    assert_equal "0.00",    event.discounted_amount
    assert_equal "PKR",     event.currency
    assert_equal "INST123", event.instrument_token
    assert_equal "card",    event.payment_method
    assert_equal "Approved", event.message
    assert event.recurring
  end

  def test_verify_invalid_signature_raises
    bad = @params.merge("validation_hash" => "deadbeef")
    assert_raises(PaygatePk::SignatureError) do
      PaygatePk::PayFast::Callback.verify!(bad)
    end
  end

  def test_verify_missing_required_param_raises
    %w[basket_id err_code validation_hash].each do |key|
      p = @params.dup
      p.delete(key)
      err = assert_raises(PaygatePk::SignatureError) do
        PaygatePk::PayFast::Callback.verify!(p)
      end
      assert_match key, err.message
    end
  end

  def test_handles_uppercase_payfast_keys
    upper = @params.transform_keys(&:upcase)
    # validation_hash must still match -- recompute with the same inputs.
    upper["VALIDATION_HASH"] = @validation
    event = PaygatePk::PayFast::Callback.verify!(upper)
    assert event.approved?
    assert_equal @basket_id, event.basket_id
  end

  def test_handles_mixed_case_keys
    mixed = {
      "Basket_Id" => @basket_id,
      "ERR_CODE" => @err_code,
      "VALIDATION_HASH" => @validation,
      "Transaction_Id" => "TXN-X",
      "RECURRING_TXN" => "false",
      "Instrument_Token" => "INST-X"
    }
    event = PaygatePk::PayFast::Callback.verify!(mixed)
    assert_equal "TXN-X",   event.transaction_id
    assert_equal "INST-X",  event.instrument_token
    refute event.recurring
  end

  def test_unapproved_err_code
    failing = @params.merge("err_code" => "97")
    failing["validation_hash"] = PaygatePk::Util::Signature::PayFast.validation_hash(
      basket_id: @basket_id, merchant_secret_key: "SKEY456",
      merchant_id: "MID123", payfast_err_code: "97"
    )
    event = PaygatePk::PayFast::Callback.verify!(failing)
    refute event.approved?
    assert_equal "97", event.code
  end

  def test_accepts_action_controller_parameters_like_objects
    fake_params = Class.new do
      def initialize(h) = @h = h
      def to_unsafe_h = @h
    end.new(@params)

    event = PaygatePk::PayFast::Callback.verify!(fake_params)
    assert event.approved?
  end
end
