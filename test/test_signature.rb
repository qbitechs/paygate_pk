# frozen_string_literal: true

require "test_helper"

class TestPayfastSignature < Minitest::Test
  def test_validation_hash
    basket_id = "BASKET123"
    merchant_secret_key = "SECRETKEY"
    merchant_id = "MID456"
    payfast_err_code = "ERR789"
    expected = OpenSSL::Digest::SHA256.hexdigest([
      basket_id,
      merchant_secret_key,
      merchant_id,
      payfast_err_code
    ].join("|"))

    actual = PaygatePk::Util::Signature::Payfast.validation_hash(
      basket_id: basket_id,
      merchant_secret_key: merchant_secret_key,
      merchant_id: merchant_id,
      payfast_err_code: payfast_err_code
    )

    assert_equal expected, actual
  end

  def test_validation_hash_with_empty_values
    expected = OpenSSL::Digest::SHA256.hexdigest(["", "", "", ""].join("|"))
    actual = PaygatePk::Util::Signature::Payfast.validation_hash(
      basket_id: "",
      merchant_secret_key: "",
      merchant_id: "",
      payfast_err_code: ""
    )
    assert_equal expected, actual
  end
end
