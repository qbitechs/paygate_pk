# frozen_string_literal: true

require_relative "paygate_pk/version"
require_relative "paygate_pk/errors"
require_relative "paygate_pk/config"

# Main module for PaygatePK
module PaygatePK
  class << self
    def configure
      yield(config)
      config.freeze!
    end

    def config
      @config ||= PaygatePK::Config.new
    end
  end
end
