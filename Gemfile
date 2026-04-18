source "https://rubygems.org"

gemspec

# Local path dep while SDK v0.2.0 is not yet published.
# Replace with `gem "abacatepay-ruby", "~> 0.2"` once the SDK is released to rubygems.
gem "abacatepay-ruby", path: "../abacatepay-ruby-sdk"

gem "rake", "~> 13.0"
gem "sqlite3"
gem "standard", require: false

group :test do
  gem "minitest", "~> 5.20"
  gem "minitest-reporters"
  gem "webmock", "~> 3.19"
end
