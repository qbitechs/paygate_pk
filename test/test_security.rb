# frozen_string_literal: true

require "test_helper"

class TestSecurity < Minitest::Test
  def test_secure_compare_equal_strings
    str1 = "abcdef123456"
    str2 = "abcdef123456"
    assert PaygatePk::Util::Security.secure_compare(str1, str2)
  end

  def test_secure_compare_different_strings
    str1 = "abcdef123456"
    str2 = "abcdef654321"
    refute PaygatePk::Util::Security.secure_compare(str1, str2)
  end

  def test_secure_compare_different_length
    str1 = "abcdef123456"
    str2 = "abcdef1234567"
    refute PaygatePk::Util::Security.secure_compare(str1, str2)
  end

  def test_secure_compare_non_string_inputs
    assert_equal false, PaygatePk::Util::Security.secure_compare(nil, "abcdef")
    assert_equal false, PaygatePk::Util::Security.secure_compare("abcdef", nil)
    assert_equal false, PaygatePk::Util::Security.secure_compare(123, "abcdef")
    assert_equal false, PaygatePk::Util::Security.secure_compare("abcdef", 123)
  end

  def test_secure_compare_empty_strings
    assert PaygatePk::Util::Security.secure_compare("", "")
  end
end
