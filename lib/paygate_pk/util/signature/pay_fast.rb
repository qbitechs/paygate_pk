# frozen_string_literal: true

require "openssl"

module PaygatePk
  module Util
    module Signature
      # PayFast IPN/return validation_hash computation.
      #
      # Per Merchant Integration Guide v2.3 §3.2.3:
      #   validation_hash = SHA256("basket_id|secured_key|merchant_id|err_code")
      #
      # Returned as a hex digest. Compared in constant time on the receiving
      # side via PaygatePk::Util::Security.secure_compare.
      module PayFast
        SEPARATOR = "|"

        def self.validation_hash(basket_id:, merchant_secret_key:, merchant_id:, payfast_err_code:)
          data = [basket_id, merchant_secret_key, merchant_id, payfast_err_code].join(SEPARATOR)
          OpenSSL::Digest::SHA256.hexdigest(data)
        end
      end
    end
  end
end
