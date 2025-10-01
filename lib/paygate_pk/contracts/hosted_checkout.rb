# lib/paygate_pk/contracts/access_token.rb
# frozen_string_literal: true

module PaygatePk
  module Contracts
    HostedCheckout = Struct.new(:provider, :basket_id, :amount, :error, :url, keyword_init: true)
  end
end
