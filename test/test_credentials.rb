# frozen_string_literal: true

require "test_helper"

class TestCredentials < Minitest::Test
  def test_returns_base64_strict_encoding_of_user_colon_pass
    expected = Base64.strict_encode64("alice:s3cret")
    assert_equal expected, PaygatePk::Util::Credentials.basic("alice", "s3cret")
  end

  def test_no_newline_in_long_strings
    long_pass = "x" * 100
    encoded = PaygatePk::Util::Credentials.basic("user", long_pass)
    refute_includes encoded, "\n", "strict_encode64 must not insert line breaks"
  end

  def test_blank_username_raises
    err = assert_raises(PaygatePk::ConfigurationError) do
      PaygatePk::Util::Credentials.basic("", "pass")
    end
    assert_match "username", err.message
  end

  def test_blank_password_raises
    err = assert_raises(PaygatePk::ConfigurationError) do
      PaygatePk::Util::Credentials.basic("user", nil)
    end
    assert_match "password", err.message
  end
end
