# frozen_string_literal: true

require "test_helper"
require "bigdecimal"

class TestCoercions < Minitest::Test
  def test_to_iso_date_passes_through_already_formatted_string
    assert_equal "2026-05-12", PaygatePk::Coercions.to_iso_date("2026-05-12")
  end

  def test_to_iso_date_formats_date
    assert_equal "2026-05-12", PaygatePk::Coercions.to_iso_date(Date.new(2026, 5, 12))
  end

  def test_to_iso_date_formats_time
    t = Time.utc(2026, 5, 12, 10, 30)
    assert_equal "2026-05-12", PaygatePk::Coercions.to_iso_date(t)
  end

  def test_to_iso_date_parses_loose_strings
    assert_equal "2026-05-12", PaygatePk::Coercions.to_iso_date("May 12, 2026")
  end

  def test_to_iso_date_nil_returns_nil
    assert_nil PaygatePk::Coercions.to_iso_date(nil)
  end

  def test_to_amount_string_integer
    assert_equal "1500", PaygatePk::Coercions.to_amount_string(1500)
  end

  def test_to_amount_string_float_is_not_scientific
    assert_equal "1500.5", PaygatePk::Coercions.to_amount_string(1500.5)
  end

  def test_to_amount_string_bigdecimal
    assert_equal "1500.25", PaygatePk::Coercions.to_amount_string(BigDecimal("1500.25"))
  end

  def test_to_amount_string_string_passthrough
    assert_equal "1500", PaygatePk::Coercions.to_amount_string("1500")
  end

  def test_to_amount_string_nil
    assert_nil PaygatePk::Coercions.to_amount_string(nil)
  end

  def test_blank_and_present_predicates
    assert PaygatePk::Coercions.blank?(nil)
    assert PaygatePk::Coercions.blank?("")
    assert PaygatePk::Coercions.blank?([])
    refute PaygatePk::Coercions.blank?("x")
    refute PaygatePk::Coercions.blank?(0)
    assert PaygatePk::Coercions.present?("x")
    refute PaygatePk::Coercions.present?(nil)
  end
end
