# frozen_string_literal: true

require_relative "lib/rollwire/version"

Gem::Specification.new do |spec|
  spec.name = "rollwire"
  spec.version = Rollwire::VERSION
  spec.authors = ["Yudai Takada"]
  spec.email = ["t.yudai92@gmail.com"]

  spec.summary = "Detect ignored ActiveRecord rollbacks in joined nested transactions"
  spec.description = <<~DESCRIPTION
    Rollwire detects ActiveRecord::Rollback exceptions that are
    silently ignored when a nested transaction joins its parent without a
    savepoint.
  DESCRIPTION
  spec.homepage = "https://github.com/ydah/rollwire"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(
          *%w[
            .github/ .idea/ .serena/ benchmark/ bin/ gemfiles/ spec/
            .gitignore .rspec .rubocop.yml Appraisals Gemfile
          ]
        )
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 7.1"

  spec.add_development_dependency "appraisal", "~> 2.5"
  spec.add_development_dependency "benchmark", ">= 0.3"
  spec.add_development_dependency "benchmark-ips", "~> 2.14"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rubocop", "~> 1.70"
  spec.add_development_dependency "sqlite3", ">= 1.7"
end
