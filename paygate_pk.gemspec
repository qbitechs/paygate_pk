# frozen_string_literal: true

require_relative "lib/paygate_pk/version"

Gem::Specification.new do |spec|
  spec.name        = "paygate_pk"
  spec.version     = PaygatePk::VERSION
  spec.authors     = ["Talha Junaid"]
  spec.email       = ["talhajunaid65@gmail.com"]
  spec.summary     = "Unified Ruby/Rails client for Pakistani payment gateways (PayFast, Easypaisa)"
  spec.description = "PaygatePk is a provider-agnostic Ruby/Rails client for payment gateways " \
                     "operating in Pakistan. 1.0 ships PayFast hosted-checkout (redirection) and " \
                     "callback verification with a one-line Rails view helper. Easypaisa REST " \
                     "(MA/OTC/Inquiry) lands in 1.1."
  spec.license     = "MIT"
  spec.homepage    = "https://github.com/qbitechs/paygate_pk"
  spec.metadata    = {
    "source_code_uri" => "https://github.com/qbitechs/paygate_pk",
    "changelog_uri"   => "https://github.com/qbitechs/paygate_pk/blob/master/CHANGELOG.md",
    "homepage_url"    => spec.homepage,
    "rubygems_mfa_required" => "true"
  }

  spec.required_ruby_version = ">= 3.1.0"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ coverage/ .git .github .circleci appveyor])
    end
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime deps
  spec.add_dependency "faraday", ">= 2.7"
  spec.add_dependency "faraday-retry", ">= 2.0"
  spec.add_dependency "json"

  # Development deps
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rubocop", "~> 1.21"
  spec.add_development_dependency "simplecov", ">= 0.22"
  spec.add_development_dependency "webmock"
end
