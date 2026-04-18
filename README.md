# pay-abacatepay

AbacatePay processor for the [Pay gem](https://github.com/pay-rails/pay) (Rails payments engine).

> [!WARNING]
> This gem is a work in progress and is **not ready for production use**. Public API may break until 1.0.

> This gem is not affiliated with AbacatePay. It is a community-maintained adapter.

## Status

- [x] Customer creation
- [ ] Charge (PIX) — planned
- [x] Subscriptions — webhook-driven lifecycle + cancel (gaps below)
- [x] Webhooks — infrastructure + subscription handlers; checkout/transparent handlers arrive later
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

## Subscriptions

Subscriptions are managed primarily through webhooks: when AbacatePay delivers `subscription.completed`, `subscription.renewed`, or `subscription.cancelled`, the gem creates or updates the corresponding `Pay::Subscription` and, for paid events, the matching `Pay::Charge` (with `data.payment.id` as `processor_id`).

### Install the dedup migration

Before deploying, run the generator and migrate:

```bash
bin/rails generate pay_abacatepay:install:migrations
bin/rails db:migrate
```

The migration creates `pay_abacatepay_processed_webhooks`, a permanent table with a unique `(event_type, event_id)` index. It protects against double-processing on AbacatePay retries — `Pay::Webhook` records are destroyed after processing, so without this table a retry that arrives after the original ACK would create a duplicate `Pay::Charge`.

### Supported operations

| Operation | Support |
|---|---|
| Webhook-driven `Pay::Subscription` create/update | yes |
| `Pay::Charge` creation per renewal | yes, idempotent via `processor_id = data.payment.id` |
| `#cancel_now!` (immediate cancellation) | yes (calls `POST /v2/subscriptions/cancel` directly — SDK does not cover) |
| `#cancel` | delegates to `#cancel_now!` with a `Rails.logger.warn`; see gap below |

### Known gaps

AbacatePay's API is narrower than Stripe's, so several `Pay::Subscription` affordances are intentionally not implemented:

- **No cancel-at-period-end.** AbacatePay cancels immediately. `#cancel` delegates to `#cancel_now!` and logs a warning so code paths that assume Stripe-like grace periods notice the divergence.
- **No plan swap.** `#swap` raises `NotImplementedError`. Cancel and create a new subscription instead.
- **No resume.** `#resume` raises `NotImplementedError`. Cancelled subscriptions cannot be reactivated.
- **No quantity changes.** `#change_quantity` raises `NotImplementedError`.
- **No `past_due` state.** AbacatePay does not emit payment-failure events, so `#past_due?` always returns `false`.
- **No `Subscriptions.retrieve` / `Subscriptions.cancel` in the SDK (v0.2.x).** Both calls are made via the SDK's Faraday client directly. Filed upstream.
- **`subscription.trial_started`.** Handler is registered but raises `NotImplementedError` — the event is not listed in `AbacatePay::Enums::Webhooks::EventTypes`, so we fail-loud until it is confirmed.

### Webhook idempotency

Each event has a permanent `id` (e.g. `log_abc123xyz`). The handler wraps its side effects in `Pay::Abacatepay::ProcessedWebhook.process!(event_type:, event_id:)`, which relies on the unique index to short-circuit retries. A second delivery of the same event returns `:already_processed` and produces no side effects.

## Webhooks

The gem mounts `POST /pay/webhooks/abacatepay` on the Pay engine (so the full URL is whatever `Pay.routes_path` resolves to — `/pay/webhooks/abacatepay` by default). Point AbacatePay's dashboard webhook at that path on your public host.

### Secret and signature

Each webhook created in AbacatePay's dashboard has its own `secret`. Expose it to the gem via Rails credentials or environment:

```yaml
# config/credentials.yml.enc
abacatepay:
  webhook_secret: wsec_xxxxx
```

Or set `ABACATEPAY_WEBHOOK_SECRET` in the environment.

Every incoming request is verified with **HMAC-SHA256** over the raw request body. The expected header is `X-Webhook-Signature`. Verification happens before any parsing or persistence; the gem delegates to the official SDK's `AbacatePay::Webhooks.verify!`.

### Response codes

| Scenario | Status |
|---|---|
| Valid signature + known event | `200 OK` |
| Valid signature + unknown event type | `200 OK` (ignored, no record) |
| Duplicate delivery (same `data.id`, same type) while a previous copy is still queued | `200 OK` (dedup, no double-processing) |
| Missing or invalid `X-Webhook-Signature` | `401 Unauthorized` |
| Malformed JSON | `400 Bad Request` |

Note: Idempotency is scoped to the window between reception and processing (`Pay::Webhook` records are destroyed by `Pay::Webhooks::ProcessJob#process!`). AbacatePay retries that arrive after a successful handler run will be re-processed; handlers must therefore be individually idempotent — or upgrade this strategy in a later phase.

### Supported events

| Event | Handler | Status |
|---|---|---|
| `checkout.completed` | `Pay::Abacatepay::Webhooks::CheckoutCompleted` | stub (Fase 4) |
| `checkout.refunded` | `Pay::Abacatepay::Webhooks::CheckoutRefunded` | stub (Fase 4) |
| `checkout.disputed` | `Pay::Abacatepay::Webhooks::CheckoutDisputed` | stub (Fase 5) |
| `checkout.lost` | `Pay::Abacatepay::Webhooks::CheckoutLost` | stub (Fase 5) |
| `transparent.completed` | `Pay::Abacatepay::Webhooks::TransparentCompleted` | stub (Fase 4) |
| `transparent.refunded` | `Pay::Abacatepay::Webhooks::TransparentRefunded` | stub (Fase 4) |
| `transparent.disputed` | `Pay::Abacatepay::Webhooks::TransparentDisputed` | stub (Fase 5) |
| `transparent.lost` | `Pay::Abacatepay::Webhooks::TransparentLost` | stub (Fase 5) |
| `subscription.completed` | `Pay::Abacatepay::Webhooks::SubscriptionCompleted` | active |
| `subscription.cancelled` | `Pay::Abacatepay::Webhooks::SubscriptionCancelled` | active |
| `subscription.renewed` | `Pay::Abacatepay::Webhooks::SubscriptionRenewed` | active |
| `subscription.trial_started` | `Pay::Abacatepay::Webhooks::SubscriptionTrialStarted` | raises `NotImplementedError` (see gap) |
| `payout.completed` | `Pay::Abacatepay::Webhooks::PayoutCompleted` | stub |
| `payout.failed` | `Pay::Abacatepay::Webhooks::PayoutFailed` | stub |
| `transfer.completed` | `Pay::Abacatepay::Webhooks::TransferCompleted` | stub |
| `transfer.failed` | `Pay::Abacatepay::Webhooks::TransferFailed` | stub |

To override or extend a handler from your own app, subscribe after the gem registers its defaults:

```ruby
# config/initializers/pay.rb
Pay::Webhooks.configure do |events|
  events.subscribe "abacatepay.subscription.renewed", ->(event) { MyJob.perform_later(event) }
end
```

## Development

```bash
bin/setup
bundle exec rake test
bundle exec standardrb
```

Tests run against an in-memory SQLite database inside `test/dummy`, using `webmock` for HTTP stubs.

## License

Released under the [MIT License](MIT-LICENSE).
