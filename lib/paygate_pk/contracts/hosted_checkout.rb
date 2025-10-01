# lib/paygate_pk/contracts/access_token.rb
# frozen_string_literal: true

module PaygatePk
  module Contracts
    HostedCheckout = Struct.new(:provider, :basket_id, :amount, :url, :raw, keyword_init: true)
  end
end
