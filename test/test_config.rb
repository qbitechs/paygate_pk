# frozen_string_literal: true

require "test_helper"

class ConfigTest < Minitest::Test
  def test_configure_and_freeze
    reset_paygate_config!
    PaygatePk.configure do |c|
      c.default_currency = "PKR"
      c.pay_fast.base_url = "https://example.test"
      c.pay_fast.merchant_id = "M1"
      c.pay_fast.secured_key = "SK"
    end
    assert_equal "PKR", PaygatePk.config.default_currency
    assert_equal "https://example.test", PaygatePk.config.pay_fast.base_url
    assert PaygatePk.config.frozen?
  end
end
