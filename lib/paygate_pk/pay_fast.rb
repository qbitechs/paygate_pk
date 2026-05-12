# frozen_string_literal: true

module PaygatePk
  # PayFast integration.
  #
  # Public API (1.0):
  #
  #   PaygatePk::PayFast::Redirect.build(...)  # => Contracts::RedirectRequest
  #   PaygatePk::PayFast::Callback.verify!(p)  # => Contracts::CallbackEvent
  #
  # Internal helpers (Auth, Endpoints) are loaded but not part of the
  # advertised surface — they may change without a major version bump.
  module PayFast
    # Shortcut to the provider-scoped config block.
    def self.config
      PaygatePk.config.pay_fast
    end
  end
end
