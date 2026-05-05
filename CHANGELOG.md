# Changelog

## 0.1.0 (2026-05-05)


### Features

* **release:** add release-please workflow + config ([692428b](https://github.com/academia-ruby/pay-abacatepay/commit/692428b3c4ce7471dd3fe7334e3efc297a8b203e))
* **release:** add RubyGems OIDC publish workflow ([0931c56](https://github.com/academia-ruby/pay-abacatepay/commit/0931c56e661b53979dbb350533c7a2fc1106c439))
* **subscriptions:** implement Customer#subscribe ([#6](https://github.com/academia-ruby/pay-abacatepay/issues/6)) ([18159be](https://github.com/academia-ruby/pay-abacatepay/commit/18159be4ea974b9f28e873e7700ebdb4dfe5bae7))
* **webhooks:** support official 3-scheme auth + add VCR cassettes ([761184b](https://github.com/academia-ruby/pay-abacatepay/commit/761184bb740423546b914a857a6fffa7d926859f))


### Bug Fixes

* **autoload:** move AR models to app/models/ for Zeitwerk ([#5](https://github.com/academia-ruby/pay-abacatepay/issues/5)) ([497112f](https://github.com/academia-ruby/pay-abacatepay/commit/497112f5b35d24dec5e3169318bd1bb405eb4b6a))
* **gemspec:** correct homepage to academia-ruby/pay-abacatepay ([3078fd9](https://github.com/academia-ruby/pay-abacatepay/commit/3078fd9e9781b005eb0475ff302d2a50c79a12e4))


### Miscellaneous Chores

* trigger pipeline validation pre-release ([80e351d](https://github.com/academia-ruby/pay-abacatepay/commit/80e351dc75fc4103e64e989b3aacc335326b268c))

## [Unreleased]

## [0.1.0.pre.3]

### Added
- `Pay::Abacatepay::Customer#subscribe(name:, plan:, methods:, quantity:, external_id:, metadata:, cycle:)` — creates an AbacatePay subscription and persists a `Pay::Abacatepay::Subscription` eagerly. Status is mapped from the API response: `PENDING` → `"incomplete"` (the typical case, reconciled to `"active"` by the `subscription.completed` webhook on the same `processor_id`); `PAID` → `"active"` already on return. `methods` accepts either an array or a single string (normalized); `quantity` defaults to `1` and must be a positive integer.
- `Pay::Abacatepay::Frequency` module with `INTERVALS`, `to_interval`, `valid?` — single source of truth shared by `Webhooks::Event#interval` and `Customer#subscribe`.
- `Pay::Abacatepay::Subscription#checkout_url` (via `store_accessor :data, :checkout_url`) so callers can redirect the payer to the first-payment URL after `subscribe`.

### Changed
- `Webhooks::Event#interval` now delegates to `Pay::Abacatepay::Frequency.to_interval` (constant `FREQUENCY_TO_INTERVAL` removed from `Event`).

### Notes
- `Customer#subscribe(metadata:)` stores values locally only — the upstream SDK's `SubscriptionClient#create` does not include `metadata` in the request body yet. Pending upstream PR.
- Trial periods unsupported: passing `trial_period_days:` or `trial_end:` raises `Pay::Abacatepay::Error` (fail-fast — silently dropping the trial would charge the customer immediately).

## [0.0.0]

### Added
- Initial scaffold with Rails engine structure
- `Pay::AbacatePay::Customer` with `api_record`, `api_record_attributes`, `update_api_record`
- Document validation (`document`/`cpf`/`cnpj`) on billable model
- Configuration via Rails credentials or environment variables
- Integration with official `abacatepay-ruby` SDK as HTTP layer
