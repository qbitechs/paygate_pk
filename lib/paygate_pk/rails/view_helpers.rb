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
    end
  end
end
