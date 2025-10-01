# lib/paygate_pk/contracts/access_token.rb
# frozen_string_literal: true

module PaygatePk
  module Contracts
    AccessToken = Struct.new(:token, :raw, keyword_init: true)
  end
end
