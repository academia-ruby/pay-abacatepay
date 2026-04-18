# pay-abacatepay

AbacatePay processor for the [Pay gem](https://github.com/pay-rails/pay) (Rails payments engine).

> [!WARNING]
> This gem is a work in progress and is **not ready for production use**. Public API may break until 1.0.

> This gem is not affiliated with AbacatePay. It is a community-maintained adapter.

## Status

- [x] Customer creation
- [ ] Charge (PIX) — planned
- [ ] Subscriptions — planned
- [ ] Webhooks — planned
- [ ] Payment methods — planned

## Installation

```bash
bundle add pay-abacatepay
```

Make sure the `pay` gem is installed and mounted: https://github.com/pay-rails/pay/blob/main/docs/1_installation.md

## Configuration

### Rails credentials

```bash
rails credentials:edit --environment=development
```

```yaml
abacatepay:
  api_key: abc_dev_xxxxx
```

### Environment variables

- `ABACATEPAY_API_KEY` — required
- `ABACATEPAY_WEBHOOK_SECRET` — optional, reserved for webhooks (not yet implemented)

### Environment (sandbox vs production)

The AbacatePay API version is inferred from the **token prefix**:

| Token prefix | API version | Typical use |
|---|---|---|
| `abc_dev_*`  | v2 | sandbox |
| `abc_live_*` | v2 | production |
| other        | v1 | legacy |

There is no environment switch to configure — give the gem the right token and it routes correctly.

## Customer

To create an AbacatePay customer the billable model **must** expose a document (CPF or CNPJ). The gem checks, in order, `document`, `cpf`, then `cnpj`. Non-digit characters are stripped before being sent to the API.

```ruby
class User < ApplicationRecord
  pay_customer default_payment_processor: :abacatepay
end

user = User.create!(email: "user@example.com", name: "Daniel", document: "123.456.789-01")
user.payment_processor.customer  # creates a customer on AbacatePay, stores processor_id
```

If the document is missing or blank, a `Pay::AbacatePay::Error` is raised before any HTTP request.

### Idempotency

AbacatePay's `POST /v2/customers/create` is idempotent by `taxId`: submitting the same document returns the existing customer with HTTP 200. The adapter stores whichever id the API returns — no client-side deduplication is needed.

### Updates

AbacatePay does not expose a customer update endpoint. `update_api_record` is a **no-op with a warning**. If you rename a user, the AbacatePay record will not reflect it until the API grows `PATCH /v2/customers`.

## Development

```bash
bin/setup
bundle exec rake test
bundle exec standardrb
```

Tests run against an in-memory SQLite database inside `test/dummy`, using `webmock` for HTTP stubs.

## License

Released under the [MIT License](MIT-LICENSE).
