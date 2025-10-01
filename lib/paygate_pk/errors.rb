# frozen_string_literal: true

module PaygatePk
  class Error < StandardError; end
  class ConfigurationError < Error; end

  class ValidationError < Error
    attr_reader :details

    def initialize(msg = "validation failed", details: {})
      @details = details
      super(msg)
    end
  end

  class HTTPError < Error
    attr_reader :status, :body

    def initialize(message = "http error", status: nil, body: nil)
      @status = status
      @body = body
      super(message)
    end
  end

  class AuthError < Error; end
  class SignatureError < Error; end
  class ProviderError < Error; end
end
