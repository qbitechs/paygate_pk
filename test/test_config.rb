# frozen_string_literal: true

require "test_helper"

class TestConfig < Minitest::Test
  def test_default_values
    assert_equal "PKR", PaygatePk.config.default_currency
    assert_equal :sandbox, PaygatePk.config.pay_fast.environment
    assert_equal "ECOMM_PURCHASE", PaygatePk.config.pay_fast.tran_type
    refute PaygatePk.config.configured?
    refute PaygatePk.config.frozen?
  end

  def test_environment_setter_validates
    assert_raises(ArgumentError) do
      PaygatePk.config.pay_fast.environment = :bogus
    end
  end

  def test_environment_setter_accepts_strings
    PaygatePk.config.pay_fast.environment = "production"
    assert_equal :production, PaygatePk.config.pay_fast.environment
  end

  def test_resolved_base_url_uses_endpoints_when_no_override
    PaygatePk.config.pay_fast.environment = :sandbox
    assert_equal "https://ipguat.apps.net.pk", PaygatePk.config.pay_fast.resolved_base_url
  end

  def test_resolved_base_url_prefers_override
    PaygatePk.config.pay_fast.base_url = "https://custom.host"
    assert_equal "https://custom.host", PaygatePk.config.pay_fast.resolved_base_url
  end

  def test_freeze_prevents_mutation_after_configure
    configure_payfast!
    assert_raises(FrozenError) do
      PaygatePk.config.pay_fast.merchant_id = "X"
    end
  end
end
