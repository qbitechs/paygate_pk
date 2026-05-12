# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# SimpleCov must be required BEFORE the code under test so it can
# instrument the gem files at load time. Without this ordering most of
# lib/ is loaded before the coverage tracker is even running, and the
# resulting report reads ~40 % when actual coverage is much higher.
begin
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
    enable_coverage :branch
  end
rescue LoadError
  # OK if not installed in some envs
end

require "minitest/autorun"
require "webmock/minitest"
require "bundler/setup"

require "paygate_pk"

module TestHelpers
  module Config
    SANDBOX_BASE_URL = "https://ipguat.apps.net.pk"

    def reset_paygate_config!
      PaygatePk.reset_config!
    end

    def configure_payfast!(
      base_url: SANDBOX_BASE_URL,
      merchant_id: "M123",
      secured_key: "SKEY",
      merchant_name: "Acme Store",
      store_id: nil,
      environment: :sandbox
    )
      PaygatePk.configure do |c|
        c.default_currency           = "PKR"
        c.pay_fast.environment       = environment
        c.pay_fast.base_url          = base_url
        c.pay_fast.merchant_id       = merchant_id
        c.pay_fast.secured_key       = secured_key
        c.pay_fast.merchant_name     = merchant_name
        c.pay_fast.store_id          = store_id
      end
    end

    EASYPAISA_SANDBOX_BASE_URL = "https://easypaystg.easypaisa.com.pk"

    def configure_easypaisa!(
      base_url: EASYPAISA_SANDBOX_BASE_URL,
      username: "EP-USER",
      password: "EP-PASS",
      store_id: "43",
      account_num: "654123987",
      environment: :sandbox
    )
      PaygatePk.configure do |c|
        c.default_currency        = "PKR"
        c.easy_paisa.environment  = environment
        c.easy_paisa.base_url     = base_url
        c.easy_paisa.username     = username
        c.easy_paisa.password     = password
        c.easy_paisa.store_id     = store_id
        c.easy_paisa.account_num  = account_num
      end
    end

    def easypaisa_credentials_header(username: "EP-USER", password: "EP-PASS")
      "Basic #{::Base64.strict_encode64("#{username}:#{password}")}"[6..]
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
