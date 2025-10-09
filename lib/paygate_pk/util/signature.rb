# lib/paygate_pk/util/signature.rb
# frozen_string_literal: true

require "openssl"

module PaygatePk
  module Util
    module Signature
      # validation_hash = SHA256("basket_id|merchant_secret_key|merchant_id|payfast_err_code")
      module Payfast
        def self.validation_hash(basket_id:, merchant_secret_key:, merchant_id:, payfast_err_code:)
          data = [basket_id, merchant_secret_key, merchant_id, payfast_err_code].join("|")
          OpenSSL::Digest::SHA256.hexdigest(data)
        end
      end
    end
  end
end
