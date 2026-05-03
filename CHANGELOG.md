# Changelog

## 0.1.0 (2026-05-03)


### Features

* **release:** add release-please workflow + config ([692428b](https://github.com/academia-ruby/pay-abacatepay/commit/692428b3c4ce7471dd3fe7334e3efc297a8b203e))
* **release:** add RubyGems OIDC publish workflow ([0931c56](https://github.com/academia-ruby/pay-abacatepay/commit/0931c56e661b53979dbb350533c7a2fc1106c439))
* **webhooks:** support official 3-scheme auth + add VCR cassettes ([761184b](https://github.com/academia-ruby/pay-abacatepay/commit/761184bb740423546b914a857a6fffa7d926859f))


### Miscellaneous Chores

* trigger pipeline validation pre-release ([80e351d](https://github.com/academia-ruby/pay-abacatepay/commit/80e351dc75fc4103e64e989b3aacc335326b268c))

## [Unreleased]

### Added
- Initial scaffold with Rails engine structure
- `Pay::AbacatePay::Customer` with `api_record`, `api_record_attributes`, `update_api_record`
- Document validation (`document`/`cpf`/`cnpj`) on billable model
- Configuration via Rails credentials or environment variables
- Integration with official `abacatepay-ruby` SDK as HTTP layer
