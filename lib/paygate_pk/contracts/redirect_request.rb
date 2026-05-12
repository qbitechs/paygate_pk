# frozen_string_literal: true

module PaygatePk
  module Contracts
    # Everything a host application needs to render a browser-side
    # redirect to the gateway's checkout page.
    #
    # Built by PaygatePk::PayFast::Redirect.build(...). Consumed by the
    # Rails view helper paygate_pk_redirect_form (or by hand-rolled
    # HTML in non-Rails apps).
    #
    #   redirect.action_url    # => "https://ipguat.apps.net.pk/Ecommerce/api/Transaction/PostTransaction"
    #   redirect.http_method   # => :post
    #   redirect.fields        # => { "MERCHANT_ID" => "...", "TOKEN" => "...", ... }
    #
    # `fields` keys are the exact PayFast field names (UPPER_SNAKE_CASE)
    # so the host app doesn't need to know the wire format.
    RedirectRequest = Struct.new(
      :provider,    # Symbol, e.g. :pay_fast
      :action_url,  # String
      :http_method, # Symbol, typically :post
      :fields,      # Hash<String,String>
      :basket_id,   # String — echoed for convenience
      :amount,      # String — echoed for convenience
      :token,       # String — the underlying ACCESS_TOKEN
      :raw,         # Hash   — the raw token-API response
      keyword_init: true
    )
  end
end
