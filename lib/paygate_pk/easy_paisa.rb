# frozen_string_literal: true

module PaygatePk
  # Easypaisa integration (REST APIs without RSA encryption, per the
  # vendor's "REST APIs without RSA Integration Guide").
  #
  # Public API (1.1):
  #
  #   PaygatePk::EasyPaisa::MobileAccount.charge(...)  # => Contracts::ChargeResult
  #   PaygatePk::EasyPaisa::OTC.create(...)            # => Contracts::ChargeResult
  #   PaygatePk::EasyPaisa::Inquiry.fetch(...)         # => Contracts::InquiryResult
  #
  # Callback (IPN) verification is deferred to 1.2 until Easypaisa
  # publishes the full IPN wire spec; for now configure the IPN URL in
  # the Easypaisa Merchant Portal and use Inquiry.fetch to poll status.
  module EasyPaisa
    def self.config
      PaygatePk.config.easy_paisa
    end
  end
end
