# PaygatePk

Unified Ruby/Rails client for Pakistani payment gateways.

**1.0 ships:** PayFast hosted-checkout (redirection flow) and callback verification, with a one-line Rails view helper.
**1.1 ships:** Easypaisa REST APIs — Mobile Account, OTC voucher, Inquiry — plus a Rails OTC voucher helper.
**1.2 will ship:** PayFast tokenization / saved-instrument charge and Easypaisa IPN verification.

The gem wraps every documented field from the *PayFast Merchant Integration Guide v2.3* and the *Easypaisa REST APIs without RSA Integration Guide*, validates required inputs, normalises dates and amounts, and returns plain Struct value objects you can pass around your Rails app.

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
gem "paygate_pk", "~> 1.1"
```

## Configure

```ruby
# config/initializers/paygate_pk.rb
PaygatePk.configure do |c|
  c.default_currency = "PKR"

  # PayFast (hosted checkout / redirection)
  c.pay_fast.environment   = Rails.env.production? ? :production : :sandbox
  c.pay_fast.merchant_id   = Rails.application.credentials.dig(:pay_fast, :merchant_id)
  c.pay_fast.secured_key   = Rails.application.credentials.dig(:pay_fast, :secured_key)
  c.pay_fast.merchant_name = "Acme Store"
  c.pay_fast.store_id      = Rails.application.credentials.dig(:pay_fast, :store_id)  # optional

  # Easypaisa (REST: Mobile Account / OTC / Inquiry)
  c.easy_paisa.environment = Rails.env.production? ? :production : :sandbox
  c.easy_paisa.username    = Rails.application.credentials.dig(:easy_paisa, :username)
  c.easy_paisa.password    = Rails.application.credentials.dig(:easy_paisa, :password)
  c.easy_paisa.store_id    = Rails.application.credentials.dig(:easy_paisa, :store_id)
  c.easy_paisa.account_num = Rails.application.credentials.dig(:easy_paisa, :account_num)  # required for Inquiry
end
```

Sandbox URLs are built in for both providers. If either hands you a bespoke staging or production host, override with `c.pay_fast.base_url = "https://..."` / `c.easy_paisa.base_url = "https://..."`.

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

## Take a payment via Easypaisa (REST)

Easypaisa offers two flavours; pick per use case:

- **Mobile Account (MA)** — customer authorises in their Easypaisa app via OTP push; merchant gets paid immediately. No redirect, no voucher.
- **OTC (Over-the-Counter)** — merchant issues a payment token; customer pays cash at any Easypaisa shop within the expiry window.

### Mobile Account

```ruby
result = PaygatePk::EasyPaisa::MobileAccount.charge(
  order_id:          "lawzo-#{payment.id}",
  amount:            1500,
  mobile_account_no: "03001234567",
  email:             "client@example.com",
  optional:          { "1" => "tenant-42" }  # optional1..5 passthrough
)

if result.success?
  payment.update!(external_transaction_id: result.transaction_id, status: :pending)
  # customer now sees the OTP prompt on their Easypaisa app
else
  flash[:alert] = "Easypaisa: #{result.response_message} (code #{result.response_code})"
end
```

### OTC voucher

```ruby
voucher = PaygatePk::EasyPaisa::OTC.create(
  order_id:     "lawzo-#{payment.id}",
  amount:       1500,
  msisdn:       "03001234567",
  email:        "client@example.com",
  token_expiry: 7.days.from_now    # Date / Time / DateTime / pre-formatted String
)
voucher.payment_token   # => "40933012" — print or show this
voucher.expires_at      # => Time
```

```erb
<%# Rails: one-line printable voucher %>
<%= paygate_pk_otc_voucher(@voucher) %>
```

### Inquiry (poll status)

Use this after issuing an OTC voucher (or for any MA transaction you didn't catch via IPN):

```ruby
status = PaygatePk::EasyPaisa::Inquiry.fetch(
  order_id:    "lawzo-#{payment.id}",
  account_num: PaygatePk.config.easy_paisa.account_num    # falls back to config
)

case status.transaction_status
when "PAID"     then payment.mark_completed!(amount: status.transaction_amount)
when "FAILED", "EXPIRED", "BLOCKED", "REVERSED" then payment.mark_failed!(reason: status.transaction_status)
when "PENDING"  then # customer hasn't visited a shop yet -- check again later
end
```

Predicates available on the result: `paid?`, `failed?`, `pending?`, `expired?`, `blocked?`, `reversed?`, `successful_lookup?`.

> **Note on IPN.** Easypaisa supports merchant-portal-configured IPN callbacks, but the wire spec isn't published in the REST guide. Until 1.2 ships `EasyPaisa::Callback.verify!`, poll `Inquiry.fetch` from a background job for OTC and on-demand for MA.

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

### `Contracts::ChargeResult` *(Easypaisa MA / OTC)*

| Field | Type | Notes |
|---|---|---|
| `provider` | `Symbol` | `:easy_paisa` |
| `basket_id` | `String` | Easypaisa `orderId` echo |
| `transaction_id` | `String?` | Ericsson EWP id (MA only) |
| `payment_token` | `String?` | Cash-redemption token (OTC only) |
| `payment_mode` | `Symbol` | `:mobile_account` or `:otc` |
| `expires_at` | `Time?` | OTC token expiry |
| `transacted_at` | `Time?` |  |
| `amount` | `String` |  |
| `currency` | `String` |  |
| `customer` | `Hash` | Echo of submitted customer info |
| `response_code` | `String` | `"0000"` on success |
| `response_message` | `String` | `responseDesc` |
| `success_code` | `String` | `"0000"` — provider's success literal |
| `raw` | `Hash` | Full provider response |

Predicates: `success?`, `failed?`, `otc?`, `mobile_account?`.

### `Contracts::InquiryResult` *(Easypaisa Inquire Transaction)*

| Field | Type | Notes |
|---|---|---|
| `provider` | `Symbol` | `:easy_paisa` |
| `basket_id` | `String` | Echoed `orderId` |
| `account_num` | `String` |  |
| `store_id` / `store_name` | `String?` |  |
| `payment_token` | `String?` | OTC only |
| `transaction_status` | `String` | `PAID`/`FAILED`/`PENDING`/`BLOCKED`/`EXPIRED`/`REVERSED` |
| `transaction_amount` | `String` |  |
| `transaction_date_time` | `String` | As Easypaisa sends, `dd/MM/yyyy hh:mm a` |
| `payment_token_expiry` | `String?` | OTC only |
| `msisdn` | `String?` |  |
| `payment_mode` | `String` | `"MA"` / `"OTC"` / `"CC"` |
| `response_code` / `response_message` | `String` |  |
| `raw` | `Hash` | Full provider response |

Predicates: `successful_lookup?`, `paid?`, `failed?`, `pending?`, `expired?`, `blocked?`, `reversed?`.

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

- **1.0** ✅ — PayFast hosted-checkout + callback verification.
- **1.1** ✅ — Easypaisa: Mobile Account, OTC voucher, Inquiry. `paygate_pk_otc_voucher` Rails helper. `c.easy_paisa.*` config block.
- **1.2** — Easypaisa IPN (`EasyPaisa::Callback.verify!`). PayFast tokenization: bearer-token auth (`/api/token`), saved instruments (`/api/user/instruments`), charge-against-saved-instrument.
- **1.x+** — Additional Pakistani gateways (JazzCash, HBL, SafePay) under the same `Contracts::RedirectRequest` / `ChargeResult` / `CallbackEvent` shapes so host code stays unchanged.

## Contributing

Issues and PRs at <https://github.com/qbitechs/paygate_pk>.

## License

MIT. See [LICENSE.txt](LICENSE.txt).
