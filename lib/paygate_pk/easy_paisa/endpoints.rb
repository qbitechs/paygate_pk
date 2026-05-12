# frozen_string_literal: true

module PaygatePk
  module EasyPaisa
    # Centralised URL map for Easypaisa REST endpoints. Picks between
    # sandbox and production based on EasyPaisaConfig#environment;
    # callers never hand-type hostnames.
    #
    # The path constants encode the three documented endpoints from the
    # vendor's "REST APIs without RSA Integration Guide".
    module Endpoints
      URLS = {
        sandbox: "https://easypaystg.easypaisa.com.pk",
        # Easypaisa has not published an official production base URL in
        # the public REST guide; merchants typically receive it on
        # go-live. Configure via `c.easy_paisa.base_url = "..."` until
        # then.
        production: "https://easypay.easypaisa.com.pk"
      }.freeze

      INITIATE_MA_PATH  = "/easypay-service/rest/v4/initiate-ma-transaction"
      INITIATE_OTC_PATH = "/easypay-service/rest/v4/initiate-otc-transaction"
      INQUIRE_PATH      = "/easypay-service/rest/v4/inquire-transaction"

      module_function

      def base_url(env)
        URLS.fetch(env) do
          raise PaygatePk::ConfigurationError, "unknown Easypaisa environment: #{env.inspect}"
        end
      end
    end
  end
end
