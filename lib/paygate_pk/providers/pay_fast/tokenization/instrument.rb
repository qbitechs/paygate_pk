# frozen_string_literal: true

module PaygatePk
  module Providers
    module PayFast
      module Tokenization
        # used to generate the bearer_token
        class Instrument < PaygatePk::Providers::PayFast::Client
          include PaygatePK::Util::Validator

          INSTRUMENTS_ENDPOINT = "/api/user/instruments"

          def list(token:, user_id:, mobile_number:, options: {})
            ensure_present!(token: token,
                            user_id: user_id,
                            mobile_number: mobile_number)

            resp = http.get(LIST_INSTRUMENTS_PATH,
                            form: body(user_id, mobile_number, options),
                            headers: { "Authorization" => "Bearer #{bearer}" })

            # Response is an array of hashes with instrument_token, account_type, description, instrument_alias
            Array(resp).map do |h|
              PaygatePk::Contracts::PaymentInstrument.new(
                instrument_token: h["instrument_token"],
                account_type: h["account_type"],
                description: h["description"],
                instrument_alias: h["instrument_alias"],
                raw: h
              )
            end
          end

          private

          def body(user_id, mobile_no, options)
            attrs = {
              "merchant_user_id" => user_id,
              "user_mobile_number" => mobile_no
            }

            # rubocop:disable Naming/VariableNumber
            attrs["customer_ip"] = options[:customer_ip] if options[:customer_ip]
            attrs["reserved_1"]  = options[:reserved_1] if options[:reserved_1]
            attrs["reserved_2"]  = options[:reserved_2] if options[:reserved_2]
            attrs["reserved_3"]  = options[:reserved_3] if options[:reserved_3]
            attrs["api_version"] = options[:api_version] if options[:api_version]
            # rubocop:enable Naming/VariableNumber

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
