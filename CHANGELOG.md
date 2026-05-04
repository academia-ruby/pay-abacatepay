# Changelog

## [Unreleased]

## [0.1.0.pre.3]

### Added
- `Pay::Abacatepay::Customer#subscribe(name:, plan:, methods:, external_id:, metadata:, cycle:)` — creates an AbacatePay subscription and persists a `Pay::Abacatepay::Subscription` (status `"incomplete"`) eagerly. Reconciled to `"active"` by the `subscription.completed` webhook on the same `processor_id`.
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
