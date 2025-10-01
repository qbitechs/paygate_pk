# frozen_string_literal: true

require "test_helper"

class TestHttpClient < Minitest::Test
  def test_post_form_and_parse_json
    client = PaygatePk::HTTP::Client.new(
      base_url: "https://example.test",
      headers: {},
      timeouts: {},
      retry_conf: {}
    )

    stub_request(:post, "https://example.test/echo")
      .with(body: "a=1&b=2", headers: { "Content-Type" => "application/x-www-form-urlencoded" })
      .to_return(status: 200, body: '{"ok":true}', headers: { "Content-Type" => "application/json" })

    resp = client.post("/echo", form: { a: 1, b: 2 })
    assert_equal true, resp["ok"]
  end

  def test_raises_http_error_on_4xx
    client = PaygatePk::HTTP::Client.new(base_url: "https://example.test", headers: {}, timeouts: {}, retry_conf: {})

    stub_request(:get, "https://example.test/fail").to_return(status: 400, body: "bad")

    err = assert_raises(PaygatePk::HTTPError) do
      client.get("/fail")
    end
    assert_equal 400, err.status
    assert_match "bad", err.body.to_s
  end
end
