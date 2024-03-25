# frozen_string_literal: true

require_relative "lib/parasort/version"

Gem::Specification.new do |spec|
  spec.name = "parasort"
  spec.version = Parasort::VERSION
  spec.authors = ["ken"]
  spec.email = ["block24block@gmail.com"]

  spec.summary = "Parallel sort"
  spec.homepage = "https://github.com/turnon/parasort"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "xenum", "~> 0.1.4"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
