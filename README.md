# PaygatePk

Unified Ruby/Rails client for Pakistani payment gateways.

**1.0 ships:** PayFast hosted-checkout (redirection flow) and callback verification, with a one-line Rails view helper.
**1.1 will ship:** Easypaisa REST APIs (Mobile Account, OTC voucher, Inquiry).
**1.2 will ship:** PayFast tokenization / saved-instrument charge.

The gem wraps every PayFast field documented in *Merchant Integration Guide v2.3*, validates required inputs, normalises dates and amounts, and returns plain Struct value objects you can pass around your Rails app.

## Requirements

- Ruby ≥ 3.1
- Faraday ≥ 2.7
- (Rails apps) ActionView ≥ 7.0 for the view helper

## Installation

```sh
bundle add paygate_pk
```

Or in a Gemfile:

```ruby
gem "paygate_pk", "~> 1.0"
```

## Configure

```ruby
# config/initializers/paygate_pk.rb
PaygatePk.configure do |c|
  c.default_currency = "PKR"

  c.pay_fast.environment   = Rails.env.production? ? :production : :sandbox
  c.pay_fast.merchant_id   = Rails.application.credentials.dig(:pay_fast, :merchant_id)
  c.pay_fast.secured_key   = Rails.application.credentials.dig(:pay_fast, :secured_key)
  c.pay_fast.merchant_name = "Acme Store"
  c.pay_fast.store_id      = Rails.application.credentials.dig(:pay_fast, :store_id)  # optional
end
```

Sandbox URL is built in. If PayFast hands you a bespoke staging or production host, override with `c.pay_fast.base_url = "https://..."`.

After the block runs the config is deep-frozen for the lifetime of the process. Use `PaygatePk.reset_config!` in console/tests to start over.

## Take a one-time payment via PayFast redirect

### 1. Build the redirect

```ruby
class Subscription::PaymentsController < ApplicationController
  def create
    @redirect = PaygatePk::PayFast::Redirect.build(
      basket_id:    "sp-#{payment.id}",
      amount:       1500,                                # rupees
      description:  "Pro plan — monthly",
      customer:     {
        mobile: current_user.mobile,                     # real 03xx mobile (mandatory)
        email:  current_user.email,
        name:   current_user.name                        # optional
      },
      success_url:  success_subscription_payments_url,
      failure_url:  failed_subscription_payments_url,
      checkout_url: webhooks_pay_fast_url,               # optional backend IPN ping
      recurring:    false
    )
  end
end
```

### 2. Render the auto-submitting form

```erb
<%# app/views/subscription/payments/create.html.erb %>
<%= paygate_pk_redirect_form(@redirect, autosubmit: true) %>
```

The customer's browser is now on PayFast. They pick a bank/card/wallet, enter their OTP, and PayFast redirects them back to your `success_url` (or `failure_url`).

### 3. Verify the return / IPN

```ruby
class Subscription::PaymentsController < ApplicationController
  def success
    event = PaygatePk::PayFast::Callback.verify!(request.parameters)
    if event.approved?
      payment = SubscriptionPayment.find_by(basket_id: event.basket_id)
      payment&.mark_completed!(transaction_id: event.transaction_id, amount: event.amount)
      redirect_to dashboard_path, notice: "Payment received."
    else
      redirect_to dashboard_path, alert: "Payment failed: #{event.message}"
    end
  rescue PaygatePk::SignatureError
    head :bad_request
  end
end
```

For the server-to-server IPN (PayFast also POSTs to `CHECKOUT_URL`), wire the same call into your webhook controller — it's the more reliable source of truth (it doesn't depend on the customer's browser making it back).

## All redirect options

```ruby
PaygatePk::PayFast::Redirect.build(
  basket_id:    "B-1001",
  amount:       1500,
  description:  "Order #1001",
  customer:     { mobile: "03001234567", email: "buyer@x.com", name: "Talha" },
  success_url:  "https://app/success",
  failure_url:  "https://app/failure",

  # — optional —
  currency:               "PKR",            # defaults to config.default_currency
  order_date:             Date.today,       # Date / Time / String, coerced to YYYY-MM-DD
  checkout_url:           "https://app/ipn",
  store_id:               "102-ABC",        # overrides config.pay_fast.store_id
  recurring:              false,
  tran_type:              "ECOMM_PURCHASE", # overrides config.pay_fast.tran_type
  processing_type:        "HYBRID_TOKEN",
  instrument_token:       "tok-from-saved-card",
  transaction_instrument: 3,                # 1=bank, 2=UnionPay, 3=card, 4=wallet

  items: [
    { sku: "SKU-1", name: "Widget", price: 100, qty: 2 },
    { sku: "SKU-2", name: "Gizmo",  price: 50,  qty: 1 }
  ],

  shipping: {
    name: "Talha", address_1: "House 9", address_2: "St 4",
    state: "Punjab", city: "Lahore", postal_code: "54000", method: "Courier"
  },
  billing:  { name: "Talha", city: "Lahore", address_1: "House 9" },

  country:              "PK",
  customer_ip:          request.remote_ip,
  merchant_customer_id: current_user.id.to_s,
  merchant_user_agent:  request.user_agent,

  extra_fields:         { "CUSTOM_X" => "value" }  # forward-compatible passthrough
)
```

## Contracts

### `Contracts::RedirectRequest`

What `Redirect.build` returns, what the view helper consumes.

| Field | Type | Notes |
|---|---|---|
| `provider` | `Symbol` | `:pay_fast` |
| `action_url` | `String` | Where the browser POSTs |
| `http_method` | `Symbol` | `:post` |
| `fields` | `Hash<String,String>` | Every PayFast form field |
| `basket_id` | `String` | Echo |
| `amount` | `String` | Echo |
| `token` | `String` | The access token |
| `raw` | `Hash` | Raw token-API response |

### `Contracts::CallbackEvent`

What `Callback.verify!` returns.

| Field | Type | Notes |
|---|---|---|
| `provider` | `Symbol` | `:pay_fast` |
| `transaction_id` | `String?` |  |
| `basket_id` | `String` |  |
| `order_date` | `String` | `YYYY-MM-DD` |
| `approved` / `approved?` | `Boolean` | `true` iff `err_code == "000"` |
| `code` | `String` | PayFast `err_code` |
| `message` | `String` | PayFast `err_msg` |
| `amount` | `String` | `transaction_amount` |
| `merchant_amount` | `String` |  |
| `discounted_amount` | `String` |  |
| `currency` | `String` |  |
| `payment_method` | `String` | "card", "account", "wallet" |
| `instrument_token` | `String?` |  |
| `recurring` | `Boolean` |  |
| `raw` | `Hash` | Original params, unmodified |

## Errors

All errors inherit from `PaygatePk::Error`:

| Class | Raised when |
|---|---|
| `ConfigurationError` | Required config is missing (e.g. `merchant_id`) |
| `ValidationError` | A required method argument is missing or blank (see `#details[:missing]`) |
| `HTTPError` | Non-2xx response from the gateway (carries `#status`, `#body`) |
| `TimeoutError` | Network timeout (subclass of `HTTPError`) |
| `ConnectionError` | DNS / SSL / refused connection (subclass of `HTTPError`) |
| `AuthError` | Token endpoint returned 2xx but the body had no `ACCESS_TOKEN` |
| `SignatureError` | Callback `validation_hash` mismatch or required field missing |
| `CapabilityNotSupported` | Provider asked for a flow it doesn't implement (1.1+) |
| `ProviderError` | Provider business-rule failure (carries `#code`, `#response`) |

## Non-Rails apps

The view helper is the only Rails-specific piece — and it's autoloaded only if `Rails::Railtie` is present. Everything else works in plain Ruby / Sinatra / Hanami:

```ruby
redirect = PaygatePk::PayFast::Redirect.build(...)
# Render redirect.fields as <input type="hidden"> in your own template.
```

## Development

```sh
bin/setup
bundle exec rake test            # 76 examples, 200 assertions, 0 failures
bundle exec rubocop
```

## Roadmap

- **1.1** — Easypaisa: Mobile Account, OTC voucher, Inquiry, IPN. New helper `paygate_pk_otc_voucher`. Adds `c.easy_paisa.*` config block.
- **1.2** — PayFast tokenization: bearer-token auth (`/api/token`), saved instruments (`/api/user/instruments`), charge-against-saved-instrument.
- **1.x+** — Additional Pakistani gateways (JazzCash, HBL, SafePay) under the same `Contracts::RedirectRequest`/`CallbackEvent` shape so host code stays unchanged.

## Contributing

Issues and PRs at <https://github.com/qbitechs/paygate_pk>.

## License

MIT. See [LICENSE.txt](LICENSE.txt).
