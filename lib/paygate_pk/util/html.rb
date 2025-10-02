# frozen_string_literal: true

require "nokogiri"

module PaygatePk
  module Util
    module Html
      module_function

      # Extract a specific <form> (default: first) into a hash of action/method/inputs
      def extract_form(html, index: 0)
        doc  = parse(html)
        form = doc.css("form")[index]
        return nil unless form

        {
          action: form["action"],
          method: (form["method"] || "GET").upcase,
          inputs: form.css("input[name]").to_h { |i| [i["name"], i["value"]] }
        }
      end

      # NEW: Return the first anchor href (or nil) – handy for redirect pages
      # Optionally pass a CSS selector (e.g., "a.pay-button") if you need a specific link.
      def first_anchor_href(html, selector: "a")
        doc = parse(html)
        a   = doc.at(selector)
        a ? a["href"] : nil
      end

      # --- internals ----------------------------------------------------------

      def parse(html)
        Nokogiri::HTML5(html)
      rescue NoMethodError
        # Fallback for environments without HTML5 parser
        Nokogiri::HTML(html)
      end
    end
  end
end
