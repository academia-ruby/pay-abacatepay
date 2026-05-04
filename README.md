# pay-abacatepay

AbacatePay processor for the [Pay gem](https://github.com/pay-rails/pay) (Rails payments engine).

> [!WARNING]
> This gem is a work in progress and is **not ready for production use**. Public API may break until 1.0.

> This gem is not affiliated with AbacatePay. It is a community-maintained adapter.

## Status

- [x] Customer creation
- [x] One-time charges — hosted checkout via `Customer#charge` + `checkout.*` webhooks
- [ ] Transparent PIX (QR Code inline) — planned (Fase 5)
- [x] Subscriptions — `Customer#subscribe` + webhook-driven lifecycle + cancel (gaps below)
- [x] Webhooks — infrastructure + subscription and checkout handlers
- [ ] Chargeback/dispute handling — planned (Fase 5)
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

## One-time charges

`Customer#charge` creates an AbacatePay **hosted checkout** and returns a struct you can redirect the payer to. A pending `Pay::Abacatepay::Charge` is persisted immediately so the app can render "payment in progress" UI and reconcile against the webhook later.

```ruby
result = user.payment_processor.charge(
  5000,                                      # amount in cents
  methods: ["PIX", "CARD"],                  # defaults shown
  return_url: "https://app.example.com/cart",
  completion_url: "https://app.example.com/thanks",
  external_id: "order-1234"                  # optional, for your reconciliation
)

redirect_to result.url                       # send the user to AbacatePay
result.id                                    # "chk_xxx" — also result.charge.processor_id
result.charge                                # Pay::Abacatepay::Charge, status: "pending"
```

### Product on-the-fly

AbacatePay's v2 `/checkouts/create` expects pre-registered products in `items[]`. When `product_id:` is omitted, the gem creates an ephemeral product via `POST /products/create` with `name: "Cobrança avulsa"` (overridable via `product_name:`). This costs an extra API call but keeps the host app's code free of product bookkeeping. Pass `product_id:` to skip this step when you manage products yourself.

### Completion flow

Once the payer completes the checkout, AbacatePay delivers a `checkout.completed` webhook. The handler:

1. Skips the event if `data.checkout.frequency != "ONE_TIME"` — subscription payments are handled by `subscription.renewed` (see [Subscriptions](#subscriptions)).
2. Locates the `Pay::Customer` by `processor_id` (no auto-creation — the customer must already exist from the app signup flow).
3. Updates the pending `Pay::Abacatepay::Charge` (same `processor_id` as `result.id`) to `status: "paid"`, filling in `amount_refunded`, `application_fee_amount`, and `created_at`. If the checkout originated outside `Customer#charge`, a new charge is created instead.

### Refunds

AbacatePay **does not expose a programmatic refund endpoint** (confirmed in SDK v0.2.0 and in the public API docs as of April 2026). Calling `Pay::Abacatepay::Charge#refund!` raises `Pay::Abacatepay::Error` with a message pointing you to the dashboard.

```
AbacatePay does not expose a refund endpoint. Process the refund in the
AbacatePay dashboard; the checkout.refunded webhook will update this
Pay::Charge automatically.
```

When the refund is issued in the dashboard, AbacatePay delivers `checkout.refunded`; the gem updates `amount_refunded` and `status: "refunded"` on the matching charge. If the charge is not found (refund for a checkout the app never registered), the handler logs a warning and no-ops.

### Status mapping

`Pay::Abacatepay::Charge` stores status in `data` via `store_accessor`. The mapping is intentionally narrow:

| AbacatePay | `Pay::Abacatepay::Charge#status` |
|---|---|
| `PENDING` | `"pending"` |
| `PAID` | `"paid"` |
| `REFUNDED` | `"refunded"` |
| `DISPUTED` | `"disputed"` (see Fase 5) |
| `EXPIRED` | *(no charge is created — the payment never succeeded)* |
| `CANCELLED` | *(no charge is created)* |

## Subscriptions

Subscriptions are managed primarily through webhooks: when AbacatePay delivers `subscription.completed`, `subscription.renewed`, or `subscription.cancelled`, the gem creates or updates the corresponding `Pay::Subscription` and, for paid events, the matching `Pay::Charge` (with `data.payment.id` as `processor_id`).

### Install the dedup migration

Before deploying, run the generator and migrate:

```bash
bin/rails generate pay_abacatepay:install:migrations
bin/rails db:migrate
```

The migration creates `pay_abacatepay_processed_webhooks`, a permanent table with a unique `(event_type, event_id)` index. It protects against double-processing on AbacatePay retries — `Pay::Webhook` records are destroyed after processing, so without this table a retry that arrives after the original ACK would create a duplicate `Pay::Charge`.

### Creating a subscription

`Customer#subscribe` creates the subscription on AbacatePay and returns a `Pay::Abacatepay::Subscription` persisted as `"incomplete"`. Redirect the payer to `subscription.checkout_url` to complete the first payment; the `subscription.completed` webhook then flips the local status to `"active"` and fills in `current_period_*`.

```ruby
subscription = user.payment_processor.subscribe(
  name: "Pro",
  plan: "prod_xxx",                   # AbacatePay product_id (must exist with cycle set)
  cycle: "MONTHLY",                   # optional; sets an optimistic current_period_end
  methods: ["PIX", "CARD"],           # defaults shown
  external_id: "order-1234",          # optional
  metadata: {release_id: order.id}    # local-only, not yet sent to AbacatePay
)

redirect_to subscription.checkout_url # first payment
subscription.processor_id             # "subs_xxx"
subscription.status                   # "incomplete" until subscription.completed webhook
```

`plan` is the AbacatePay `product_id`. Cycle is a Product property, not a Subscription property — pass `cycle:` here purely so the gem can compute `current_period_end` immediately; otherwise it stays `nil` until the webhook arrives.

Trial periods are unsupported: passing `trial_period_days:` or `trial_end:` raises `Pay::Abacatepay::Error`. AbacatePay simply has no trial primitive, and silently dropping it would charge the customer immediately — fail-fast surfaces the divergence.

### Supported operations

| Operation | Support |
|---|---|
| `Customer#subscribe` (create subscription from code) | yes (PIX/CARD; no trial; `cycle:` optional) |
| Webhook-driven `Pay::Subscription` create/update | yes |
| `Pay::Charge` creation per renewal | yes, idempotent via `processor_id = data.payment.id` |
| `#cancel_now!` (immediate cancellation) | yes (calls `POST /v2/subscriptions/cancel` directly — SDK does not cover) |
| `#cancel` | delegates to `#cancel_now!` with a `Rails.logger.warn`; see gap below |

### Known gaps

AbacatePay's API is narrower than Stripe's, so several `Pay::Subscription` affordances are intentionally not implemented:

- **No cancel-at-period-end.** AbacatePay cancels immediately. `#cancel` delegates to `#cancel_now!` and logs a warning so code paths that assume Stripe-like grace periods notice the divergence.
- **No trial periods.** Passing `trial_period_days:` or `trial_end:` to `Customer#subscribe` raises `Pay::Abacatepay::Error`.
- **Cycle is a Product property.** Pass `cycle:` to `subscribe` for an immediate `current_period_end`; otherwise it stays `nil` until the `subscription.completed` webhook arrives.
- **`metadata` not yet sent to AbacatePay.** `Customer#subscribe(metadata:)` stores values locally on `Pay::Subscription#metadata` only — the SDK's `SubscriptionClient#create` doesn't include `metadata` in the request body yet. Pending upstream PR.
- **No plan swap.** `#swap` raises `NotImplementedError`. Cancel and create a new subscription instead. (AbacatePay added `POST /v2/subscriptions/change-plan` on 2026-05-04 — implementation pending.)
- **No resume.** `#resume` raises `NotImplementedError`. Cancelled subscriptions cannot be reactivated.
- **No quantity changes.** `#change_quantity` raises `NotImplementedError`.
- **No `past_due` state.** `#past_due?` always returns `false`. (AbacatePay added `subscription.payment_failed` on 2026-04-29 — handler implementation pending.)
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
| `checkout.completed` | `Pay::Abacatepay::Webhooks::CheckoutCompleted` | active (one-time only; subscription payments skipped) |
| `checkout.refunded` | `Pay::Abacatepay::Webhooks::CheckoutRefunded` | active |
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
