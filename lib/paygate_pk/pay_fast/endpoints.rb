# frozen_string_literal: true

module PaygatePk
  module PayFast
    # Centralised URL map. Selecting between sandbox and production is a
    # config flag (PayFastConfig#environment); callers never hand-type
    # hostnames.
    #
    # If/when PayFast hands you a bespoke staging host, set
    #   PaygatePk.config.pay_fast.base_url = "https://..."
    # to override the env-derived value.
    module Endpoints
      URLS = {
        sandbox: "https://ipguat.apps.net.pk",
        # PayFast has not published an official production base URL in
        # the v2.3 doc; merchants typically receive it on go-live.
        # Configure via `c.pay_fast.base_url = "..."` until then.
        production: "https://ipg1.apps.net.pk"
      }.freeze

      GET_ACCESS_TOKEN_PATH = "/Ecommerce/api/Transaction/GetAccessToken"
      POST_TRANSACTION_PATH = "/Ecommerce/api/Transaction/PostTransaction"

      module_function

      def base_url(env)
        URLS.fetch(env) do
          raise PaygatePk::ConfigurationError, "unknown PayFast environment: #{env.inspect}"
        end
      end

      def post_transaction_url(env_or_base)
        host = URLS[env_or_base] || env_or_base
        "#{host}#{POST_TRANSACTION_PATH}"
      end
    end
  end
end
