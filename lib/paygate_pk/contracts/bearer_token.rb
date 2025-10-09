# lib/paygate_pk/contracts/access_token.rb
# frozen_string_literal: true

module PaygatePk
  module Contracts
    # Normalized wrapper for /token response.
    # Some docs show only "refresh_token"; we expose both.
    BearerToken = Struct.new(
      :access_token,  # String or nil
      :refresh_token, # String or nil
      :expiry,        # Integer seconds or nil
      :code,          # Provider code string or nil
      :message,       # Provider message string or nil
      :raw,           # Full response Hash
      keyword_init: true
    )
  end
end
