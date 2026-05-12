# frozen_string_literal: true

require "test_helper"

class TestPaygatePk < Minitest::Test
  def test_version_number_present
    refute_nil ::PaygatePk::VERSION
    assert_match(/\A\d+\.\d+\.\d+/, ::PaygatePk::VERSION)
  end

  def test_configure_freezes_config
    PaygatePk.configure do |c|
      c.pay_fast.merchant_id = "M1"
      c.pay_fast.secured_key = "SK"
      c.pay_fast.merchant_name = "Acme"
    end
    assert PaygatePk.config.frozen?
    assert PaygatePk.config.pay_fast.frozen?
    assert PaygatePk.config.configured?
  end

  def test_reset_config_yields_fresh_mutable_config
    configure_payfast!
    assert PaygatePk.config.frozen?
    PaygatePk.reset_config!
    refute PaygatePk.config.frozen?
    refute PaygatePk.config.configured?
  end
end
