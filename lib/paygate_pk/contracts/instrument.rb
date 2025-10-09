# frozen_string_literal: true

module PaygatePk
  module Contracts
    Instrument = Struct.new(
      :instrument_token, :account_type, :description, :instrument_alias, :raw,
      keyword_init: true
    )
  end
end
