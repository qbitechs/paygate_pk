# frozen_string_literal: true

require "test_helper"

begin
  require "action_view"
  require "action_view/base"
rescue LoadError
  $stderr.puts "Skipping view helper tests: action_view not installed"
end

if defined?(ActionView::Base)
  require "paygate_pk/rails/view_helpers"

  class TestViewHelpers < Minitest::Test
    class Renderer < ActionView::Base.with_empty_template_cache
      include PaygatePk::Rails::ViewHelpers
    end

    def setup
      super
      @renderer = Renderer.new(ActionView::LookupContext.new([]), {}, nil)
      @redirect = PaygatePk::Contracts::RedirectRequest.new(
        provider:    :pay_fast,
        action_url:  "https://gateway/pay",
        http_method: :post,
        fields: {
          "MERCHANT_ID" => "M1",
          "TOKEN"       => "t-1",
          "BASKET_ID"   => "B-1"
        },
        basket_id: "B-1",
        amount:    "1500",
        token:     "t-1"
      )
    end

    def test_renders_form_with_action_and_method
      html = @renderer.paygate_pk_redirect_form(@redirect, autosubmit: false)
      assert_match %r{<form[^>]+action="https://gateway/pay"}, html
      assert_match %r{<form[^>]+method="post"}, html
    end

    def test_renders_hidden_inputs_for_each_field
      html = @renderer.paygate_pk_redirect_form(@redirect, autosubmit: false)
      assert_match %r{<input[^>]+name="MERCHANT_ID"[^>]+value="M1"}, html
      assert_match %r{<input[^>]+name="TOKEN"[^>]+value="t-1"}, html
      assert_match %r{<input[^>]+name="BASKET_ID"[^>]+value="B-1"}, html
    end

    def test_autosubmit_emits_submit_script
      html = @renderer.paygate_pk_redirect_form(@redirect, autosubmit: true)
      assert_match %r{<script[^>]*>.*submit\(\).*</script>}m, html
    end

    def test_no_submit_button_when_autosubmit
      html = @renderer.paygate_pk_redirect_form(@redirect, autosubmit: true)
      refute_match %r{<button}, html
    end

    def test_visible_submit_button_when_not_autosubmit
      html = @renderer.paygate_pk_redirect_form(
        @redirect, autosubmit: false, submit_label: "Go!"
      )
      assert_match %r{<button[^>]+type="submit"[^>]*>Go!</button>}, html
    end

    def test_custom_form_id_is_used
      html = @renderer.paygate_pk_redirect_form(
        @redirect, autosubmit: true, html: { id: "my-form" }
      )
      assert_match %r{id="my-form"}, html
      assert_match %r{my-form}, html # also in script
    end
  end
end
