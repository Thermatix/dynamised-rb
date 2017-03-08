# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dynamised/meta'

Gem::Specification.new do |spec|
  spec.name          = "Dynamised"
  spec.version       = Dynamised::META::Version
  spec.authors       = ["Martin Becker"]
  spec.email         = ["mbeckerwork@gmail.com"]

  spec.summary       = %q{A tool to allow you to build site crawling page scrapers.}
  spec.description   = Dynamised::META::Description
  spec.homepage      = "https://github.com/Thermatix/dynamised-rb"
  spec.license       = "MIT"


  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
# {tty-spinner nokogiri awesome_print
  spec.add_runtime_dependency "tty-spinner", "~> 0.4"
  spec.add_runtime_dependency "nokogiri", "~> 1.7"
  spec.add_runtime_dependency "awesome_print", "~> 1.7"
  spec.add_runtime_dependency "commander", "~> 4.4"

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
end
