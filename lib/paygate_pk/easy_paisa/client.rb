# frozen_string_literal: true

module PaygatePk
  module EasyPaisa
    # Internal shared HTTP wrapper for the three Easypaisa REST endpoints.
    # Not advertised on the public surface; MobileAccount / OTC /
    # Inquiry instantiate it directly and consume the parsed response.
    #
    # Responsibilities:
    # - Validate provider config (username + password + store_id) before
    #   touching the network; raises ConfigurationError with a list of
    #   missing keys.
    # - Build the Credentials header (Base64Strict("user:pass")).
    # - POST a JSON body, returning the decoded Hash.
    # - Convert any non-Hash response (Easypaisa always returns JSON, so
    #   this is defensive) into a ProviderError with the raw body
    #   attached.
    class Client
      SUCCESS_CODE = "0000"

      def initialize(config: PaygatePk::EasyPaisa.config, http: nil)
        @config = config
        @http   = http
      end

      # POSTs json to the given path. Returns the decoded Hash. Does NOT
      # interpret responseCode -- the caller decides whether non-0000
      # warrants raising vs. surfacing as a result with success? == false.
      def post(path, json:)
        ensure_config!
        http.post(path, json: json, headers: auth_headers)
      end

      def success_code
        SUCCESS_CODE
      end

      private

      def http
        @http ||= PaygatePk::HTTP::Client.new(
          base_url: @config.resolved_base_url,
          headers: { "Accept" => "application/json" }
        )
      end

      def auth_headers
        {
          "Credentials" => PaygatePk::Util::Credentials.basic(@config.username, @config.password)
        }
      end

      def ensure_config!
        missing = []
        missing << :username if Coercions.blank?(@config.username)
        missing << :password if Coercions.blank?(@config.password)
        missing << :store_id if Coercions.blank?(@config.store_id)
        return if missing.empty?

        raise PaygatePk::ConfigurationError, "Easypaisa config missing: #{missing.join(", ")}"
      end
    end
  end
end
