# frozen_string_literal: true

require "test_helper"

class TestPayFastSignature < Minitest::Test
  def test_validation_hash_matches_expected_sha256
    basket_id           = "BASKET123"
    merchant_secret_key = "SECRETKEY"
    merchant_id         = "MID456"
    payfast_err_code    = "ERR789"
    expected = OpenSSL::Digest::SHA256.hexdigest(
      [basket_id, merchant_secret_key, merchant_id, payfast_err_code].join("|")
    )

    actual = PaygatePk::Util::Signature::PayFast.validation_hash(
      basket_id: basket_id,
      merchant_secret_key: merchant_secret_key,
      merchant_id: merchant_id,
      payfast_err_code: payfast_err_code
    )

    assert_equal expected, actual
  end

  def test_doc_example_hash
    # Example from Merchant Integration Guide v2.3 §3.2.3:
    #   "BAS-01|jdnkaabcks|102|000" -> e8192a7554dd699975adf39619c703a492392edf5e416a61e183866ecdf6a2a2
    actual = PaygatePk::Util::Signature::PayFast.validation_hash(
      basket_id: "BAS-01",
      merchant_secret_key: "jdnkaabcks",
      merchant_id: "102",
      payfast_err_code: "000"
    )
    assert_equal "e8192a7554dd699975adf39619c703a492392edf5e416a61e183866ecdf6a2a2", actual
  end

  def test_validation_hash_with_empty_values
    expected = OpenSSL::Digest::SHA256.hexdigest(["", "", "", ""].join("|"))
    actual = PaygatePk::Util::Signature::PayFast.validation_hash(
      basket_id: "", merchant_secret_key: "", merchant_id: "", payfast_err_code: ""
    )
    assert_equal expected, actual
  end
end
