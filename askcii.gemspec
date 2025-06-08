# frozen_string_literal: true

require_relative 'lib/askcii/version'

Gem::Specification.new do |spec|
  spec.name          = 'askcii'
  spec.version       = Askcii::VERSION
  spec.authors       = ['Roel Bondoc']
  spec.email         = ['roelbondoc@example.com']

  spec.summary       = 'Command line application for LLM interactions'
  spec.description   = 'A terminal-friendly interface for interacting with LLM models'
  spec.homepage      = 'https://github.com/roelbondoc/askcii'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.6.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'bin'
  spec.executables   = ['askcii']
  spec.require_paths = ['lib']

  spec.add_dependency 'amalgalite', '~> 1.9'
  spec.add_dependency 'ruby_llm', '1.3.0'
  spec.add_dependency 'sequel', '~> 5.92'

  spec.add_development_dependency 'minitest', '~> 5.25'
  spec.add_development_dependency 'rake', '~> 13.0'
end
