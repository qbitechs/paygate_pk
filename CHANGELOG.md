# Changelog

## [1.0.0] - 2026-05-12

### Overview

Complete rewrite focused on **PayFast hosted-checkout (redirection)**.
The gem now ships everything needed to take a one-time payment in three
files — initializer, controller, and a one-line ERB. The 0.x server-to-
server `Checkout` class that POSTed to `PostTransaction` has been removed;
that endpoint is browser-side per PayFast's Merchant Integration Guide,
and the 0.x implementation was architecturally wrong.

### Public API (new)

```ruby
PaygatePk::PayFast::Redirect.build(...)   # → Contracts::RedirectRequest
PaygatePk::PayFast::Callback.verify!(p)   # → Contracts::CallbackEvent
```

Rails view helper:

```erb
<%= paygate_pk_redirect_form(@redirect, autosubmit: true) %>
```

### Added

- `PaygatePk::PayFast::Redirect` — fetches an access token, then assembles
  every mandatory + optional PayFast form field documented in Merchant
  Integration Guide v2.3 §3.2. Handles `items[]` arrays, shipping/billing
  blocks, recurring flag, store override, currency override, and
  free-form `extra_fields` passthrough.
- `PaygatePk::PayFast::Callback` — replaces the 0.x `Webhook` class.
  Down-cases all incoming param keys once at entry so PayFast's
  mixed-case `Recurring_txn`/`Instrument_token`/`PaymentName` and
  lower-snake `basket_id`/`err_code`/`validation_hash` all work without
  caller intervention.
- `PaygatePk::PayFast::Endpoints` — URL map keyed by environment
  (`:sandbox`, `:production`); `c.pay_fast.base_url=` override still
  supported for custom staging hosts.
- `PaygatePk::Rails::ViewHelpers#paygate_pk_redirect_form` —
  auto-submitting form helper with CSP-nonce support, autoloaded via
  a Railtie when the gem boots inside a Rails app.
- `Contracts::RedirectRequest` — `{ provider, action_url, http_method,
  fields, basket_id, amount, token, raw }`.
- `Contracts::CallbackEvent` — universal IPN/return shape with
  `approved?` predicate. Future Easypaisa callbacks will return the
  same struct.
- `PaygatePk::Coercions` — `to_iso_date`, `to_amount_string`,
  `blank?`/`present?`.
- `Config::PayFastConfig#environment` toggle, validated setter.
- `Config::PayFastConfig#merchant_name` (was hardcoded to `""` in 0.x).
- `HTTP::Client`: full Faraday error mapping (`TimeoutError`,
  `ConnectionError`, `HTTPError` cover-all), memoised connection,
  log redaction for `SECURED_KEY`/`Authorization`/`Credentials`.
- `Errors::CapabilityNotSupported`, `Errors::TimeoutError`,
  `Errors::ConnectionError`, `Errors::ProviderError`.

### Changed

- Public namespace flattened from `PaygatePk::Providers::PayFast::*`
  to `PaygatePk::PayFast::*`.
- `Util::Signature::Payfast` renamed to `Util::Signature::PayFast`.
- `Config#frozen?` renamed to `Config#configured?`. `Config#freeze!`
  now actually deep-freezes (was a no-op `@frozen = true` boolean).
- `Contracts::AccessToken#token` is now an alias for `#value`; the
  primary field name is `value` to stay consistent with future
  bearer/charge tokens.
- Required Ruby version: `>= 3.1.0` (matches the 0.x README claim;
  gemspec used to say `>= 2.6.0` despite Faraday 2 effectively needing
  3.1).
- `spec.require_paths` reduced from `%w[lib test]` to `["lib"]` so
  test helpers are no longer shipped on the gem load path.
- `nokogiri` removed from runtime deps (no longer parsing HTML
  responses now that `Checkout` is gone).
- Test suite rewritten end-to-end. 76 tests / 200 assertions /
  96 % line coverage / 77 % branch coverage.

### Removed

- `Providers::PayFast::Client`              — dual facade/base-class
  identity replaced by namespace module + `Endpoints`.
- `Providers::PayFast::Checkout`            — server-to-server POST
  to `PostTransaction` was wrong for the redirection flow.
- `Providers::PayFast::Webhook`             — renamed to `Callback`.
- `Providers::PayFast::Tokenization::Token`/`Instrument` — deferred
  to 1.2 alongside the saved-instrument charge endpoint. Source
  preserved in git history.
- `Util::Html`                              — no longer needed.
- `Contracts::HostedCheckout`               — replaced by
  `RedirectRequest`.
- `Contracts::WebhookEvent`                 — renamed to
  `CallbackEvent` with broader field coverage and an `approved?`
  predicate.
- `Contracts::BearerToken`/`Instrument`     — deferred to 1.2.

### Fixed

- Callback key-casing bug. The 0.x `Webhook#verify!` only aliased
  two specific PascalCase keys; in production PayFast sends a mix of
  lower-snake and PascalCase keys that the old code couldn't read.
- `ORDER_DATE` is now coerced to `YYYY-MM-DD` per spec; the 0.x
  flow let timestamped strings through silently.
- `SIGNATURE` is generated fresh per call (PayFast doc: "A random
  string value"). The 0.x integration in office-management was
  shipping the literal demo string `"SOMERANDOM-STRING"` to
  production.
- `CURRENCY_CODE` is now plumbed through `Redirect.build`; the 0.x
  `Checkout` read the global `PaygatePk.config.default_currency` and
  ignored per-call values, silently mismatching auth and checkout.
- All `Faraday::Error` subclasses (timeout, connection failure, 5xx,
  SSL) now surface as typed `PaygatePk` errors instead of escaping
  as raw `Faraday::*` exceptions.
- `SECURED_KEY` no longer leaks into Rails logs when a debug logger
  is wired up.
- `Config#freeze!` is now a real deep-freeze.

### Migration from 0.x

| 0.x | 1.0 |
|-----|-----|
| `PaygatePk::Providers::PayFast::Auth.new.get_access_token(...)` | `PaygatePk::PayFast::Redirect.build(...)` calls `Auth` internally — you usually don't need it directly. |
| `PaygatePk::Providers::PayFast::Checkout.new.create!(opts: {...})` | `PaygatePk::PayFast::Redirect.build(...)` (kwargs, no `opts:` wrapper). |
| `PaygatePk::Providers::PayFast::Webhook.new.verify!(params)` | `PaygatePk::PayFast::Callback.verify!(params)` |
| `c.pay_fast.base_url = "..."` (hand-typed sandbox host) | `c.pay_fast.environment = :sandbox` (override only when PayFast hands you a custom staging URL). |
| Hand-built 18-field hidden form ERB | `<%= paygate_pk_redirect_form(@redirect) %>` |

## [0.2.0] - 2025-10-10

- Added: IPN verification, Tokenization 3.1 & 3.15.
- Changed: renamed token methods (old name deprecated).
- Security: switched to stdlib constant-time compare (no Rack dep).

## [0.1.0] - 2025-10-01

- Initial release.
- PayFast: GetAccessToken + Checkout (HTML redirect parsing).
- Config, errors, HTTP client, tests, CI scaffolding.
