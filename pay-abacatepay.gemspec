require_relative "lib/pay/abacatepay/version"

Gem::Specification.new do |spec|
  spec.name = "pay-abacatepay"
  spec.version = Pay::Abacatepay::VERSION
  spec.authors = ["Daniel Moreira"]
  spec.email = ["daniel@invenio.dev.br"]

  spec.summary = "AbacatePay processor for the Pay gem (Rails payments engine)."
  spec.description = "Community-maintained AbacatePay adapter for pay-rails/pay. Not affiliated with AbacatePay."
  spec.homepage = "https://github.com/danielmoreira/pay-abacatepay"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir["app/**/*", "lib/**/*", "MIT-LICENSE", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "pay", "~> 11.0"
  spec.add_dependency "abacatepay-ruby", ">= 0.2.0"
end
