# frozen_string_literal: true

require_relative "lib/paygate_pk/version"

Gem::Specification.new do |spec|
  spec.name       = "paygate_pk"
  spec.version    = PaygatePk::VERSION
  spec.authors    = ["Talha Junaid"]
  spec.email      = ["talhajunaid65@gmail.com"]
  spec.summary    = "Unified Ruby wrapper for PayFast"
  spec.description = "Provider-agnostic Ruby/Rails client for PayFast: checkout, webhooks/IPN verification,
                      tokenized & recurring payments."
  spec.license     = "MIT"
  spec.homepage    = "https://github.com/qbitechs/paygate_pk"
  spec.metadata    = {
    "source_code_uri" => "https://github.com/qbitechs/paygate_pk",
    "changelog_uri" => "https://github.com/qbitechs/paygate_pk/blob/main/CHANGELOG.md",
    "homepage_url" => spec.homepage
  }

  spec.required_ruby_version = ">= 2.6.0"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
