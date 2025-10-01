# frozen_string_literal: true

require "test_helper"

class PayFastCheckoutTest < Minitest::Test
  def setup
    super
    configure_payfast!(base_url: "https://example.test")
  end

  def test_create_checkout_success_html_anchor
    html = <<~HTML
      <html><body><a href="https://gateway.payfast/redirect/ABC">Click to pay</a></body></html>
    HTML

    stub_request(:post, "https://example.test/Ecommerce/api/Transaction/PostTransaction")
      .to_return(status: 200, body: html, headers: { "Content-Type" => "text/html" })

    checkout = PaygatePk::Providers::PayFast::Checkout.new(config: PaygatePk.config.pay_fast)

    opts = {
      token: "t-abc",
      basket_id: "B-1001",
      amount: 1500,
      customer: { mobile: "03001234567", email: "buyer@example.com" },
      success_url: "https://app/success",
      failure_url: "https://app/failure",
      description: "Order #1001",
      checkout_mode: :immediate
    }

    hc = checkout.create!(opts: opts)

    assert_equal :payfast, hc.provider
    assert_equal "B-1001", hc.basket_id
    assert_equal 1500, hc.amount
    # Requires HostedCheckout to have :url (see patch below)
    assert_equal "https://gateway.payfast/redirect/ABC", hc.url
  end

  def test_create_checkout_missing_fields
    checkout = PaygatePk::Providers::PayFast::Checkout.new(config: PaygatePk.config.pay_fast)

    err = assert_raises(PaygatePk::ValidationError) do
      checkout.create!(opts: { token: "", basket_id: "", amount: nil, customer: {}, success_url: "", failure_url: "",
                               description: "" })
    end
    assert_match "missing required args", err.message
  end
end
