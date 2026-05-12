# frozen_string_literal: true

module PaygatePk
  module Rails
    # Action View helpers, auto-included into ActionView::Base by the
    # Railtie when the gem boots inside a Rails app.
    module ViewHelpers
      DEFAULT_FORM_ID = "paygate-pk-redirect-form"
      SUBMIT_LABEL    = "Pay now"

      # Renders the auto-submitting redirect form for any provider that
      # produces a Contracts::RedirectRequest.
      #
      #   <%= paygate_pk_redirect_form(@redirect) %>
      #
      # Options:
      #   autosubmit: true (default) — emits a script tag that submits
      #               the form on page load. Set to false to render a
      #               visible "Pay now" button instead.
      #   html:       { id:, class:, data: { ... }, ... } — passed
      #               straight to the <form> tag. `id` falls back to
      #               "paygate-pk-redirect-form".
      #   submit_label: button label when autosubmit is false.
      def paygate_pk_redirect_form(redirect, autosubmit: true, html: {}, submit_label: SUBMIT_LABEL)
        form_id   = html[:id] || DEFAULT_FORM_ID
        form_html = render_form(redirect, form_id, html, autosubmit, submit_label)
        return form_html unless autosubmit

        form_html + autosubmit_script(form_id)
      end

      # Renders a printable Easypaisa OTC voucher from a
      # Contracts::ChargeResult (from PaygatePk::EasyPaisa::OTC.create).
      #
      #   <%= paygate_pk_otc_voucher(@voucher) %>
      #
      # Options:
      #   html:   { class:, ... } — outer container overrides
      #   title:  heading text (default "Pay at any Easypaisa shop")
      #   instructions: array of bullet strings; falls back to a sane
      #                 default that mentions the expiry time
      def paygate_pk_otc_voucher(result, html: {}, title: "Pay at any Easypaisa shop", instructions: nil)
        return otc_voucher_failure(result, html) unless result.success? && result.payment_token.present?

        container_attrs = otc_voucher_attrs(html, success: true)
        body = otc_voucher_success_body(result, title: title, instructions: instructions || default_otc_instructions(result))

        content_tag(:div, body, container_attrs)
      end

      private

      def render_form(redirect, form_id, html, autosubmit, submit_label)
        attrs = {
          id: form_id,
          action: redirect.action_url,
          method: redirect.http_method.to_s,
          accept_charset: "UTF-8"
        }.merge(html.except(:id))

        content_tag(:form, attrs) do
          hidden = redirect.fields.map do |name, value|
            tag.input(type: "hidden", name: name.to_s, value: value.to_s)
          end
          submit = autosubmit ? "".html_safe : tag.button(submit_label, type: "submit")
          safe_join(hidden + [submit])
        end
      end

      def autosubmit_script(form_id)
        javascript_tag(
          "document.getElementById(#{form_id.to_json}).submit();",
          nonce: respond_to?(:content_security_policy_nonce) ? content_security_policy_nonce : nil
        )
      end

      # ── OTC voucher rendering ─────────────────────────────────────

      def otc_voucher_attrs(html, success:)
        default_class = if success
          "paygate-pk-otc-voucher rounded-2xl border border-emerald-200 bg-emerald-50 p-6"
        else
          "paygate-pk-otc-voucher paygate-pk-otc-voucher--failed rounded-2xl border border-rose-200 bg-rose-50 p-6"
        end

        html.merge(class: [ default_class, html[:class] ].compact.join(" "))
      end

      def otc_voucher_success_body(result, title:, instructions:)
        safe_join([
          content_tag(:h3, title, class: "text-base font-bold text-slate-900 mb-4"),
          otc_voucher_token_block(result),
          otc_voucher_meta(result),
          otc_voucher_instructions(instructions)
        ])
      end

      def otc_voucher_token_block(result)
        content_tag(:div, class: "rounded-xl bg-white border border-emerald-200 px-5 py-4 mb-4 text-center") do
          safe_join([
            content_tag(:p, "Payment token", class: "text-xs font-semibold uppercase tracking-wide text-slate-500"),
            content_tag(:p, result.payment_token, class: "mt-1 font-mono text-2xl font-bold tracking-widest text-slate-900")
          ])
        end
      end

      def otc_voucher_meta(result)
        rows = []
        rows << [ "Amount",  "PKR #{result.amount}" ]
        rows << [ "Mobile",  result.customer[:msisdn] ] if result.customer[:msisdn].present?
        rows << [ "Expires", otc_voucher_format_time(result.expires_at) ] if result.expires_at
        rows << [ "Order",   result.basket_id ]

        content_tag(:dl, class: "grid grid-cols-2 gap-y-2 text-sm mb-4") do
          safe_join(rows.flat_map do |label, value|
            [
              content_tag(:dt, label, class: "text-slate-500"),
              content_tag(:dd, value, class: "text-right font-semibold text-slate-900")
            ]
          end)
        end
      end

      def otc_voucher_instructions(instructions)
        content_tag(:ul, class: "list-disc pl-5 space-y-1 text-xs text-slate-600") do
          safe_join(instructions.map { |line| content_tag(:li, line) })
        end
      end

      def default_otc_instructions(result)
        expiry = result.expires_at ? otc_voucher_format_time(result.expires_at) : nil
        [
          "Visit any Easypaisa shop with the token above.",
          "Pay PKR #{result.amount} in cash and quote your token to the agent.",
          expiry ? "Pay before #{expiry} — the token expires after that." : nil
        ].compact
      end

      def otc_voucher_failure(result, html)
        container_attrs = otc_voucher_attrs(html, success: false)
        body = safe_join([
          content_tag(:h3, "Voucher unavailable", class: "text-base font-bold text-rose-900 mb-2"),
          content_tag(:p, result.response_message.presence || "Easypaisa did not issue a token for this order.",
                      class: "text-sm text-rose-700")
        ])
        content_tag(:div, body, container_attrs)
      end

      def otc_voucher_format_time(value)
        return value if value.is_a?(String)
        return nil unless value.respond_to?(:strftime)

        value.strftime("%d %b %Y, %I:%M %p")
      end
    end
  end
end
