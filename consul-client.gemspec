# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.authors       = ["Xavier Shay"]
  gem.email         = ["contact@xaviershay.com"]
  gem.description   =
    %q{Ruby client library for Consul HTTP API.}
  gem.summary       = %q{
    Ruby client library for Consul HTTP API, providing both a thin wrapper
    around the raw API and higher level behaviours for operating in a Consul
    environment.
  }
  gem.homepage      = "http://github.com/xaviershay/consul-client"

  gem.executables   = []
  gem.required_ruby_version = '>= 2.1.2'
  gem.files         = Dir.glob("{spec,lib}/**/*.rb") + %w(
                        README.md
                        consul-client.gemspec
                      )
  gem.test_files    = Dir.glob("spec/**/*.rb")
  gem.name          = "consul-client"
  gem.require_paths = ["lib"]
  gem.license       = "Apache 2.0"
  gem.version       = '0.1.0'
  gem.has_rdoc      = false
end
