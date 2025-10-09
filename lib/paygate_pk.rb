# frozen_string_literal: true

require_relative "paygate_pk/version"
require_relative "paygate_pk/errors"
require_relative "paygate_pk/config"
require_relative "paygate_pk/http/client"

# Contracts used by the endpoint
require_relative "paygate_pk/contracts/access_token"
require_relative "paygate_pk/contracts/hosted_checkout"
require_relative "paygate_pk/contracts/bearer_token"
require_relative "paygate_pk/contracts/instrument"

# PayFast
require_relative "paygate_pk/providers/pay_fast/client"
require_relative "paygate_pk/providers/pay_fast/auth"
require_relative "paygate_pk/providers/pay_fast/checkout"
require_relative "paygate_pk/providers/pay_fast/tokenization/token"

require_relative "paygate_pk/util/html"

# Main module for PaygatePk
module PaygatePk
  class << self
    def configure
      yield(config)
      config.freeze!
    end

    def config
      @config ||= PaygatePk::Config.new
    end
  end
end
