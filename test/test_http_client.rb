# frozen_string_literal: true

require "test_helper"

class TestHttpClient < Minitest::Test
  def client
    PaygatePk::HTTP::Client.new(
      base_url: "https://example.test",
      headers: {},
      timeouts: {},
      retry_conf: {}
    )
  end

  def test_post_form_and_parse_json
    stub_request(:post, "https://example.test/echo")
      .with(body: "a=1&b=2",
            headers: { "Content-Type" => "application/x-www-form-urlencoded" })
      .to_return(status: 200, body: '{"ok":true}',
                 headers: { "Content-Type" => "application/json" })

    resp = client.post("/echo", form: { a: 1, b: 2 })
    assert_equal true, resp["ok"]
  end

  def test_post_json_body
    stub_request(:post, "https://example.test/json")
      .with(body: { "k" => "v" }.to_json,
            headers: { "Content-Type" => "application/json" })
      .to_return(status: 200, body: "{}", headers: {})

    client.post("/json", json: { k: "v" })
  end

  def test_get_with_query_params
    stub_request(:get, "https://example.test/q")
      .with(query: { "a" => "1" })
      .to_return(status: 200, body: '{"ok":1}')

    resp = client.get("/q", params: { a: 1 })
    assert_equal 1, resp["ok"]
  end

  def test_4xx_raises_typed_error_with_status_and_body
    stub_request(:get, "https://example.test/fail")
      .to_return(status: 400, body: "bad")

    err = assert_raises(PaygatePk::HTTPError) { client.get("/fail") }
    assert_equal 400, err.status
    assert_match "bad", err.body.to_s
  end

  def test_5xx_raises_http_error_not_bare_faraday
    stub_request(:get, "https://example.test/oops")
      .to_return(status: 500, body: "boom")

    err = assert_raises(PaygatePk::HTTPError) { client.get("/oops") }
    assert_equal 500, err.status
  end

  def test_connection_failure_is_mapped
    stub_request(:get, "https://example.test/nope").to_raise(Faraday::ConnectionFailed)

    assert_raises(PaygatePk::ConnectionError) { client.get("/nope") }
  end

  def test_timeout_is_mapped
    stub_request(:get, "https://example.test/slow").to_raise(Faraday::TimeoutError)

    assert_raises(PaygatePk::TimeoutError) { client.get("/slow") }
  end

  def test_non_json_response_passes_through_as_string
    stub_request(:get, "https://example.test/html")
      .to_return(status: 200, body: "<html>oops</html>",
                 headers: { "Content-Type" => "text/html" })

    resp = client.get("/html")
    assert_kind_of String, resp
    assert_match "oops", resp
  end

  def test_user_agent_defaults_when_config_blank
    PaygatePk.config.user_agent = ""
    stub_request(:get, "https://example.test/ua")
      .with(headers: { "User-Agent" => "paygate_pk" })
      .to_return(status: 200, body: "{}")

    client.get("/ua")
  end
end
