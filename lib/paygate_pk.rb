# frozen_string_literal: true

require_relative "paygate_pk/version"
require_relative "paygate_pk/errors"
require_relative "paygate_pk/coercions"
require_relative "paygate_pk/config"

require_relative "paygate_pk/util/security"
require_relative "paygate_pk/util/signature/pay_fast"
require_relative "paygate_pk/util/credentials"

require_relative "paygate_pk/http/client"

require_relative "paygate_pk/contracts/access_token"
require_relative "paygate_pk/contracts/redirect_request"
require_relative "paygate_pk/contracts/callback_event"
require_relative "paygate_pk/contracts/charge_result"
require_relative "paygate_pk/contracts/inquiry_result"

require_relative "paygate_pk/pay_fast"
require_relative "paygate_pk/pay_fast/endpoints"
require_relative "paygate_pk/pay_fast/auth"
require_relative "paygate_pk/pay_fast/redirect"
require_relative "paygate_pk/pay_fast/callback"

require_relative "paygate_pk/easy_paisa"
require_relative "paygate_pk/easy_paisa/endpoints"
require_relative "paygate_pk/easy_paisa/client"
require_relative "paygate_pk/easy_paisa/mobile_account"
require_relative "paygate_pk/easy_paisa/otc"
require_relative "paygate_pk/easy_paisa/inquiry"

require_relative "paygate_pk/rails/railtie" if defined?(Rails::Railtie)

# Unified Ruby/Rails client for Pakistani payment gateways.
#
#   PaygatePk.configure do |c|
#     # PayFast (hosted checkout / redirection)
#     c.pay_fast.environment   = :sandbox
#     c.pay_fast.merchant_id   = ENV["PAYFAST_MERCHANT_ID"]
#     c.pay_fast.secured_key   = ENV["PAYFAST_SECURED_KEY"]
#     c.pay_fast.merchant_name = "Acme Store"
#
#     # Easypaisa (REST APIs)
#     c.easy_paisa.environment = :sandbox
#     c.easy_paisa.username    = ENV["EASYPAISA_USERNAME"]
#     c.easy_paisa.password    = ENV["EASYPAISA_PASSWORD"]
#     c.easy_paisa.store_id    = ENV["EASYPAISA_STORE_ID"]
#   end
#
#   redirect = PaygatePk::PayFast::Redirect.build(...)
#   event    = PaygatePk::PayFast::Callback.verify!(request.parameters)
#   result   = PaygatePk::EasyPaisa::MobileAccount.charge(...)
#   voucher  = PaygatePk::EasyPaisa::OTC.create(...)
#   status   = PaygatePk::EasyPaisa::Inquiry.fetch(...)
module PaygatePk
  class << self
    def configure
      yield(config)
      config.freeze!
      config
    end

    def config
      @config ||= Config.new
    end

    # Test/dev helper. Discards the current (possibly frozen) config so
    # that a fresh PaygatePk.configure call can re-seed it.
    def reset_config!
      @config = Config.new
    end
  end
end
