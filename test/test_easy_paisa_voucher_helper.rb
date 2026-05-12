# frozen_string_literal: true

require "test_helper"

begin
  require "action_view"
  require "action_view/base"
rescue LoadError
  warn "Skipping OTC voucher helper tests: action_view not installed"
end

if defined?(ActionView::Base)
  require "paygate_pk/rails/view_helpers"

  class TestEasyPaisaVoucherHelper < Minitest::Test
    class Renderer < ActionView::Base.with_empty_template_cache
      include PaygatePk::Rails::ViewHelpers
    end

    def setup
      super
      @renderer = Renderer.new(ActionView::LookupContext.new([]), {}, nil)
    end

    def successful_voucher(payment_token: "40933012")
      PaygatePk::Contracts::ChargeResult.new(
        provider: :easy_paisa,
        basket_id: "order-001",
        transaction_id: nil,
        payment_token: payment_token,
        payment_mode: :otc,
        expires_at: Time.new(2030, 5, 1, 18, 30),
        transacted_at: nil,
        amount: "1500",
        currency: "PKR",
        customer: { msisdn: "03001234567", email: "x@y.com" },
        response_code: "0000",
        response_message: "SUCCESS",
        success_code: "0000",
        raw: {}
      )
    end

    def failed_voucher
      successful_voucher(payment_token: nil).then do |v|
        PaygatePk::Contracts::ChargeResult.new(**v.to_h, payment_token: nil, response_code: "0008",
                                                         response_message: "PAYMENT METHOD NOT ENABLED")
      end
    end

    def test_renders_token_amount_mobile_expiry_and_reference
      html = @renderer.paygate_pk_otc_voucher(successful_voucher)

      assert_match "40933012", html
      assert_match "PKR 1500", html
      assert_match "03001234567", html
      assert_match "01 May 2030", html
      assert_match "order-001", html
      assert_match "Pay at any Easypaisa shop", html
    end

    def test_uses_default_instructions
      html = @renderer.paygate_pk_otc_voucher(successful_voucher)
      assert_match "Visit any Easypaisa shop", html
      assert_match "Pay PKR 1500 in cash", html
    end

    def test_accepts_custom_title_and_instructions
      html = @renderer.paygate_pk_otc_voucher(
        successful_voucher,
        title: "Bayar di kedai Easypaisa",
        instructions: ["Bring this token.", "Have exact cash."]
      )

      assert_match "Bayar di kedai Easypaisa", html
      assert_match "Bring this token.", html
      assert_match "Have exact cash.", html
      refute_match "Visit any Easypaisa shop", html
    end

    def test_failed_result_renders_failure_card_not_a_token
      html = @renderer.paygate_pk_otc_voucher(failed_voucher)

      assert_match "Voucher unavailable", html
      assert_match "PAYMENT METHOD NOT ENABLED", html
      refute_match "40933012", html
      assert_match "paygate-pk-otc-voucher--failed", html
    end

    def test_html_class_overrides_merge
      html = @renderer.paygate_pk_otc_voucher(successful_voucher, html: { class: "shadow-xl" })
      assert_match(/class="paygate-pk-otc-voucher [^"]*shadow-xl"/, html)
    end
  end
end
