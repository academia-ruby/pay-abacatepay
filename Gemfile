source "https://rubygems.org"

gemspec

# Forked SDK with API/webhook compliance fixes (PR pending upstream).
# Replace with `gem "abacatepay-ruby", "~> 0.2"` once upstream merges + publishes.
gem "abacatepay-ruby", github: "academia-ruby/abacatepay-ruby-sdk", branch: "fix/strict-spec-compliance"

gem "rake", "~> 13.0"
gem "sqlite3"
gem "standard", require: false

group :test do
  gem "minitest", "~> 5.20"
  gem "minitest-reporters"
  gem "webmock", "~> 3.19"
  gem "vcr", "~> 6.3"
  gem "bundler-audit", "~> 0.9"
end
