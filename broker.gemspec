# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'broker/version'

Gem::Specification.new do |spec|
  spec.name          = "broker"
  spec.version       = Broker::VERSION
  spec.authors       = ["villins"]
  spec.email         = ["linshao512@gmail.com"]
  spec.summary       = %q{ wrapper micro service broker }
  spec.description   = %q{ wrapper micro service broker }
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency             'redis'
  spec.add_dependency             'hiredis'
  spec.add_dependency             'msgpack'
  spec.add_dependency             'beaneater', '~> 1.0.0'
  spec.add_dependency             'logging'

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency 'minitest', '~> 5.8', '>= 5.8.4'
  spec.add_development_dependency "rake"
  # spec.add_development_dependency "pry"

end
