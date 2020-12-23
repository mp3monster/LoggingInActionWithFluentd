

Gem::Specification.new do |spec|
  spec.name    = "fluent-plugin-out-redislist"
  spec.version = "0.1.0"
  spec.authors = ["Phil Wilkins"]
  spec.email   = ["someone at mp3monster.org"]

  spec.summary   = %q{This provides an Fluentd Output to Redis List it has been developed to support a Chapter of Unified Logging with Fluentd by Manning}
  spec.description   = spec.summary
  spec.homepage      = "http://mp3monster.org"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files`.split($\)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "test-unit", "~> 3.0"
  spec.add_runtime_dependency "fluentd", [">= 0.14.10", "< 2"]
  spec.add_runtime_dependency "redis"
end
