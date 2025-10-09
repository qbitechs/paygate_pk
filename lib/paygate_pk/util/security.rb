# lib/paygate_pk/util/security.rb
# frozen_string_literal: true

require "openssl"

module PaygatePk
  module Util
    # Constant-time string compare without Rack/ActiveSupport
    module Security
      module_function

      # Constant-time string compare without Rack/ActiveSupport
      def secure_compare(expected_hash, incoming_hash)
        return false unless expected_hash.is_a?(String) && incoming_hash.is_a?(String)
        return false unless expected_hash.bytesize == incoming_hash.bytesize

        OpenSSL.fixed_length_secure_compare(expected_hash, incoming_hash)
      rescue NoMethodError
        # Fallback if Ruby/OpenSSL is too old (very rare on modern Ruby)
        # XOR-based constant-time fallback
        diff = 0
        expected_hash.bytes.zip(incoming_hash.bytes) { |x, y| diff |= (x ^ y) }
        diff.zero?
      end
    end
  end
end
