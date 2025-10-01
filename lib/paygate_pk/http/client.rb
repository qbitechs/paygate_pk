# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"
require "securerandom"

module PaygatePK
  module HTTP
    # Simple HTTP client using Faraday
    class Client
      def initialize(base_url:, headers: {}, timeouts: {}, retry_conf: {}, logger: nil)
        @conn = Faraday.new(url: base_url) do |f|
          f.request :retry,
                    max: retry_conf[:max] || 2,
                    interval: retry_conf[:interval] || 0.2,
                    backoff_factor: retry_conf[:backoff_factor] || 2.0,
                    retry_statuses: retry_conf[:retry_statuses] || [429, 500, 502, 503, 504]

          f.request :url_encoded
          f.response :raise_error
          f.adapter Faraday.default_adapter
        end

        @headers  = headers
        @timeouts = timeouts
        @logger   = logger
      end

      def post(path, json: nil, form: nil, headers: {})
        request(:post, path, json: json, form: form, headers: headers)
      end

      def get(path, params: {}, headers: {})
        request(:get, path, params: params, headers: headers)
      end

      private

      def request(method, path, json: nil, form: nil, params: nil, headers: {})
        resp = @conn.run_request(method, path, nil, base_headers.merge(headers)) do |req|
          req.options.timeout      = @timeouts[:read_timeout] if @timeouts[:read_timeout]
          req.options.open_timeout = @timeouts[:open_timeout] if @timeouts[:open_timeout]
          req.params.update(params) if params

          if json
            req.headers["Content-Type"] = "application/json"
            req.body = JSON.generate(json)
          elsif form
            req.headers["Content-Type"] = "application/x-www-form-urlencoded"
            req.body = URI.encode_www_form(form)
          end
        end

        log_response(resp)
        parse_body(resp)
      rescue Faraday::ClientError => e
        body = e.response ? e.response[:body] : nil
        raise PaygatePK::HTTPError.new(e.message,
                                       status: e.response && e.response[:status],
                                       body: body)
      end

      def base_headers
        {
          "User-Agent" => PaygatePK.config.user_agent || "paygate_pk",
          "X-Request-Id" => SecureRandom.uuid
        }.merge(@headers)
      end

      def parse_body(resp)
        b = resp.body
        if b.is_a?(String) && !b.empty?
          begin
            JSON.parse(b)
          rescue StandardError
            b
          end
        else
          b
        end
      end

      def log_response(resp)
        return unless @logger

        @logger.info("paygate_pk http #{resp.env.method.upcase} #{resp.env.url} -> #{resp.status}")
      end
    end
  end
end
