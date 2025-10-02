# PaygatePk

Unified Ruby wrapper for PayFast (and soon Easypaisa) payments in Pakistan.

This gem provides a clean, provider-agnostic interface to obtain access tokens and create hosted checkouts with PayFast. It wraps HTTP details, validates required fields, and exposes simple, Ruby-friendly objects. Rails-friendly configuration is included; IPN verification and recurring/tokenized flows are on the roadmap.

## Requirements

- Ruby ≥ 3.1
- Faraday (runtime, included by gemspec)
- Nokogiri (runtime, for HTML redirect parsing, included)
- (Dev) Byebug, SimpleCov, RuboCop — optional

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add "paygate_pk", "~> 0.1.0"

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install "paygate_pk", "~> 0.1.0"

## Usage

# Initializer

```ruby
# config/initializers/paygate_pk.rb

PaygatePk.configure do |c|
  c.default_currency = "PKR"
  c.user_agent = "paygate_pk/#{PaygatePk::VERSION}"

  # PayFast base host only; endpoints include /Ecommerce/api internally

  c.payfast.base_url = "https://ipguat.apps.net.pk"
  c.payfast.merchant_id = ENV.fetch("PAYFAST_MERCHANT_ID")
  c.payfast.secured_key = ENV.fetch("PAYFAST_SECURED_KEY")
  c.payfast.checkout_mode = :immediate # or :delayed

  # Optional: tune timeouts & retries

  c.timeouts = { open_timeout: 5, read_timeout: 10 }
  c.retry = { max: 2, interval: 0.2, backoff_factor: 2.0, retry_statuses: [429, 500, 502, 503, 504] }
end
```

## QuickStart

# 1) Get Access Token (PayFast)

```ruby
auth = PaygatePk::Providers::PayFast::Auth.new(config: PaygatePk.config.payfast)

token_obj = auth.get_access_token(
basket_id: "B-1001",
amount: 1500

# currency: "PKR", # optional; defaults to PaygatePk.config.default_currency

# endpoint: "/Ecommerce/api/Transaction/GetAccessToken" # optional override

)

puts token_obj.token # => "ACCESS_TOKEN_STRING"

```

# 2) Create Hosted Checkout (PayFast)

```ruby
checkout = PaygatePk::Providers::PayFast::Checkout.new(config: PaygatePk.config.payfast)

hc = checkout.create!(opts: {
  token:       token_obj.token,
  basket_id:   "B-1001",
  amount:      1500, # paisa (Rs 15.00)
  customer:    { mobile: "03001234567", email: "buyer@example.com" },
  success_url: "https://your-app.example.com/payments/success",
  failure_url: "https://your-app.example.com/payments/failure",
  description: "Order #1001"
  # checkout_mode: :immediate,  # optional; default from config
  # endpoint: "/Ecommerce/api/Transaction/PostTransaction" # optional override
})

hc.url # => "https://gateway.payfast/redirect/ABC123"
# Redirect the buyer to hc.url
```

# Error handling

All errors inherit from PaygatePk::Error:

- PaygatePk::ConfigurationError — missing/invalid configuration (e.g., merchant_id, secured_key, or base_url).
- PaygatePk::ValidationError — missing required method arguments or required form fields.
- PaygatePk::HTTPError — network/HTTP failure (wraps response status & body).
- PaygatePk::AuthError — auth call succeeded at HTTP level but token missing/invalid in body.
- PaygatePk::SignatureError — reserved for webhook/IPN verification (upcoming).
- PaygatePk::ProviderError — reserved for provider business-rule failures.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/paygate_pk. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/paygate_pk/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the PaygatePk project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/paygate_pk/blob/master/CODE_OF_CONDUCT.md).
