# frozen_string_literal: true

module PaygatePk
  module Contracts
    # Normalized server-side notification from PayFast (IPN) or other providers.
    WebhookEvent = Struct.new(
      :provider,          # Symbol e.g., :payfast
      :transaction_id,    # String or nil
      :basket_id,         # String
      :order_date,        # String (YYYY-MM-DD) or Time/Date if you coerce later
      :approved,          # Boolean (true if err_code == "000")
      :code,              # Provider code, e.g., "000"
      :message,           # Human-readable message
      :amount,            # String/Integer (as received)
      :currency,          # String "PKR" etc.
      :instrument_token,  # String or nil (for tokenized flows)
      :recurring,         # Boolean
      :raw,               # Original params Hash (unmodified input)
      keyword_init: true
    )
  end
end
