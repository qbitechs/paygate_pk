# frozen_string_literal: true

require "bigdecimal"

module PaygatePk
  module Providers
    module PayFast
      module Tokenization
        # used to generate the bearer_token
        class Token < PaygatePk::Providers::PayFast::Client
          TOKEN_ENDPOINT = "/api/token"

          # 3.1 Authentication Access Token
          # Required: merchant_id, secured_key, grant_type
          # Optional: customer_ip, reserved_1..3, api_version
          # Returns: PaygatePk::Contracts::BearerToken
          def get(grant_type:, options: {})
            @config.base_url = "https://apipxyuat.apps.net.pk:8443/"
            mid = config.merchant_id
            sec = config.secured_key

            ensure_present!(merchant_id: mid, secured_key: sec, grant_type: grant_type)

            resp = http.post(TOKEN_ENDPOINT, form: body(mid, sec, grant_type, options))

            PaygatePk::Contracts::BearerToken.new(
              access_token: resp["token"], # if present
              refresh_token: resp["refresh_token"], # shown in doc example
              expiry: resp["expiry"],
              code: resp["code"],
              message: resp["message"],
              raw: resp
            )
          end

          private

          def body(mid, sec, grant_type, options)
            attrs = {
              "merchant_id" => mid,
              "secured_key" => sec,
              "grant_type" => grant_type
            }
            attrs["customer_ip"] = options[:customer_ip] if options[:customer_ip]
            attrs["reserved_1"]  = options[:reserved1] if options[:reserved1]
            attrs["reserved_2"] = options[:reserved2] if options[:reserved2]
            attrs["reserved_3"]  = options[:reserved3] if options[:reserved3]
            attrs["api_version"] = options[:api_version] if options[:api_version]

            attrs
          end

          def ensure_present!(**pairs)
            missing = pairs.select { |_k, v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }.keys
            raise PaygatePk::ValidationError, "missing required args: #{missing.join(", ")}" unless missing.empty?
          end
        end
      end
    end
  end
end
