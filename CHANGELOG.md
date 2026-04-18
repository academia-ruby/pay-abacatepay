# Changelog

## [Unreleased]

### Added
- Initial scaffold with Rails engine structure
- `Pay::AbacatePay::Customer` with `api_record`, `api_record_attributes`, `update_api_record`
- Document validation (`document`/`cpf`/`cnpj`) on billable model
- Configuration via Rails credentials or environment variables
- Integration with official `abacatepay-ruby` SDK as HTTP layer
