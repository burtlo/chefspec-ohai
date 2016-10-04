# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'chefspec/ohai/version'

Gem::Specification.new do |spec|
  spec.name          = "chefspec-ohai"
  spec.version       = Chefspec::Ohai::VERSION
  spec.authors       = ["Franklin Webber"]
  spec.email         = ["franklin@chef.io"]

  spec.summary       = %q{Provides additional RSpec helpers to test Ohai plugins}
  spec.description   = %q{Ohai plugins often go untested within the cookbooks that we create.
When an Ohai plugin fails it is often a trial-and-error process that requires us to redeploy it.
This gem provides additional helpers to RSpec to be used in conjunction with ChefSpec to test your plugins.}
  spec.homepage      = "https://github.com/burtlo/chefspec-ohai"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"
end
