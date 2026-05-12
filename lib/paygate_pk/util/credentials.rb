# frozen_string_literal: true

require "base64"

module PaygatePk
  module Util
    # Header-credential helpers used by REST providers that authenticate
    # with a static username/password pair.
    #
    # Easypaisa: header key "Credentials", value is Base64Strict of
    # "username:password" -- HTTP-Basic style but WITHOUT the literal
    # "Basic " scheme prefix.
    module Credentials
      module_function

      # Returns Base64Strict("user:pass"). Raises if either is blank
      # -- empty credentials would silently authenticate as a different
      # principal and produce baffling 401s downstream.
      def basic(username, password)
        raise PaygatePk::ConfigurationError, "username is required" if Coercions.blank?(username)
        raise PaygatePk::ConfigurationError, "password is required" if Coercions.blank?(password)

        Base64.strict_encode64("#{username}:#{password}")
      end
    end
  end
end
