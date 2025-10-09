# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "webmock/minitest"
require "bundler/setup"

require "paygate_pk"

begin
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
    enable_coverage :branch
  end
rescue LoadError
  # ok if not installed in some envs
end

module TestHelpers
  module Config
    def reset_paygate_config!
      PaygatePk.instance_variable_set(:@config, PaygatePk::Config.new)
    end

    def configure_payfast!(base_url: "https://example.test", merchant_id: "M123", secured_key: "SKEY",
                           api_base_url: nil)
      PaygatePk.configure do |c|
        c.default_currency = "PKR"
        c.pay_fast.base_url    = base_url
        c.pay_fast.merchant_id = merchant_id
        c.pay_fast.secured_key = secured_key
        c.pay_fast.api_base_url = api_base_url
      end
    end
  end
end

module Minitest
  class Test
    include TestHelpers::Config

    def setup
      reset_paygate_config!
      WebMock.disable_net_connect!
    end
  end
end
