# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"
require "securerandom"

module PaygatePk
  module HTTP
    # Thin Faraday wrapper used by every provider endpoint class.
    #
    # Responsibilities:
    # - Build a single memoised Faraday connection per Client instance.
    # - Map every Faraday::Error subclass to a typed PaygatePk error so
    #   consumers can rescue PaygatePk::Error and catch everything.
    # - Optional info-level logging with secret redaction.
    # - Decode JSON response bodies opportunistically; passes through raw
    #   String when the body isn't valid JSON (some PayFast endpoints
    #   return text/HTML on error pages).
    class Client
      # Field/header names whose values get masked in log output.
      SENSITIVE_KEYS = %w[
        SECURED_KEY secured_key password Password
        Credentials credentials Authorization authorization
      ].freeze

      MASK = "[REDACTED]"

      def initialize(base_url:, headers: {}, timeouts: nil, retry_conf: nil, logger: nil)
        @base_url   = base_url
        @headers    = headers
        @timeouts   = timeouts   || PaygatePk.config.timeouts
        @retry_conf = retry_conf || PaygatePk.config.retry
        @logger     = logger     || PaygatePk.config.logger
      end

      def post(path, json: nil, form: nil, headers: {})
        request(:post, path, json: json, form: form, headers: headers)
      end

      def get(path, params: {}, headers: {})
        request(:get, path, params: params, headers: headers)
      end

      private

      def conn
        @conn ||= Faraday.new(url: @base_url) do |f|
          f.request :retry,
                    max: @retry_conf[:max] || 2,
                    interval: @retry_conf[:interval] || 0.2,
                    backoff_factor: @retry_conf[:backoff_factor] || 2.0,
                    retry_statuses: @retry_conf[:retry_statuses] || [429, 500, 502, 503, 504]
          f.request :url_encoded
          f.response :raise_error
          f.adapter Faraday.default_adapter
        end
      end

      # rubocop:disable Metrics/AbcSize
      def request(method, path, json: nil, form: nil, params: nil, headers: {})
        resp = conn.run_request(method, path, nil, merged_headers(headers)) do |req|
          apply_timeouts(req)
          req.params.update(params) if params && !params.empty?
          apply_body(req, json: json, form: form)
        end

        log_response(method, path, resp.status, form: form, json: json)
        parse_body(resp)
      rescue Faraday::TimeoutError => e
        raise PaygatePk::TimeoutError.new(e.message, status: nil, body: nil)
      rescue Faraday::ConnectionFailed => e
        raise PaygatePk::ConnectionError.new(e.message, status: nil, body: nil)
      rescue Faraday::Error => e
        raise PaygatePk::HTTPError.new(
          e.message,
          status: e.response&.dig(:status),
          body: e.response&.dig(:body)
        )
      end
      # rubocop:enable Metrics/AbcSize

      def merged_headers(headers)
        base_headers.merge(headers)
      end

      def apply_timeouts(req)
        req.options.open_timeout = @timeouts[:open_timeout] if @timeouts[:open_timeout]
        req.options.timeout      = @timeouts[:read_timeout] if @timeouts[:read_timeout]
      end

      def apply_body(req, json:, form:)
        if json
          req.headers["Content-Type"] = "application/json"
          req.body = JSON.generate(json)
        elsif form
          req.headers["Content-Type"] = "application/x-www-form-urlencoded"
          req.body = URI.encode_www_form(form)
        end
      end

      def base_headers
        ua = PaygatePk.config.user_agent.to_s
        ua = "paygate_pk" if ua.empty? # PayFast rejects empty user agents
        {
          "User-Agent" => ua,
          "X-Request-Id" => SecureRandom.uuid
        }.merge(@headers)
      end

      def parse_body(resp)
        body = resp.body
        return body unless body.is_a?(String) && !body.empty?

        JSON.parse(body)
      rescue JSON::ParserError
        body
      end

      def log_response(method, path, status, form:, json:)
        return unless @logger

        sanitised = redact(form || json)
        @logger.info(
          "paygate_pk #{method.to_s.upcase} #{path} status=#{status} body=#{sanitised.inspect}"
        )
      end

      def redact(body)
        return nil if body.nil?
        return body unless body.is_a?(Hash)

        body.each_with_object({}) do |(k, v), acc|
          acc[k] = SENSITIVE_KEYS.include?(k.to_s) ? MASK : v
        end
      end
    end
  end
end
