# frozen_string_literal: true

module PaygatePk
  module Contracts
    # A PayFast ACCESS_TOKEN, fetched server-to-server via Auth#call,
    # then plugged into the redirect form.
    #
    # `value` is the bare token string. `token` is kept as an alias so
    # old call sites continue to read naturally (`access_token.token`).
    AccessToken = Struct.new(:value, :raw, keyword_init: true) do
      alias_method :token, :value
    end
  end
end
