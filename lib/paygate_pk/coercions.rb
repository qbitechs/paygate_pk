# frozen_string_literal: true

require "date"

module PaygatePk
  # Small set of input normalisers shared across providers.
  # All methods are pure and side-effect-free.
  module Coercions
    module_function

    DATE_ISO = "%Y-%m-%d"

    # Returns "YYYY-MM-DD" (PayFast's ORDER_DATE format) for Date/Time/DateTime
    # or a String already in that shape. nil-tolerant.
    def to_iso_date(value)
      return nil if value.nil?
      return value if value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/)

      case value
      when Date, Time, DateTime then value.strftime(DATE_ISO)
      when String               then Date.parse(value).strftime(DATE_ISO)
      else
        raise ArgumentError, "cannot coerce #{value.inspect} to ISO date"
      end
    end

    # Render a numeric amount as a non-scientific decimal String. PayFast
    # accepts TXNAMT as a string; 1500 → "1500", 1500.5 → "1500.5".
    def to_amount_string(value)
      return nil if value.nil?

      case value
      when Integer then value.to_s
      when Float, Rational, BigDecimal then format("%g", value)
      when String  then value
      else value.to_s
      end
    end

    def blank?(value)
      value.nil? || (value.respond_to?(:empty?) && value.empty?)
    end

    def present?(value)
      !blank?(value)
    end
  end
end
