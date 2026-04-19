# TODO: substituir fixtures inferidas por payloads reais do sandbox

Os arquivos abaixo foram **inferidos** na Fase 4 a partir do payload real de
`subscription_renewed.json` (Fase 3). A doc oficial do AbacatePay não documenta
os payloads de `checkout.completed` / `checkout.refunded`, então a estrutura
pode divergir em campos, casing ou nomes.

Arquivos afetados:

- `checkout_completed_one_time.json`
- `checkout_completed_subscription.json`
- `checkout_refunded.json`

## O que fazer (sessão Sonnet futura)

1. Daniel dispara um one-time checkout real em sandbox (PIX e/ou CARD) e captura
   o payload do webhook `checkout.completed`. Substitui `checkout_completed_one_time.json`.
2. Daniel dispara um checkout de subscription e captura o `checkout.completed`
   correspondente. Substitui `checkout_completed_subscription.json` (especialmente
   para confirmar que `data.checkout.frequency` vem mesmo como `"SUBSCRIPTION"` —
   é o campo usado pelo handler para pular subscription payments).
3. Daniel dispara um refund pelo dashboard e captura o `checkout.refunded`.
   Substitui `checkout_refunded.json`.
4. Após substituir, rodar:
   ```bash
   bundle exec rake test
   ```
   e ajustar assertivas que quebrarem. Candidatos prováveis a divergência:
   - casing de chaves (`camelCase` vs `snake_case`)
   - presença/ausência de nó `payment` no `checkout.refunded`
   - campo `checkout.frequency` pode vir como `ONE_TIME` / `SUBSCRIPTION` ou como
     um enum diferente
   - `data.checkout.customerId` vs `data.customer.id` — Event wrapper usa `data.customer.id`
5. Atualizar `Pay::Abacatepay::Webhooks::Event` em `lib/pay/abacatepay/webhooks/event.rb`
   se novos campos relevantes aparecerem.

## Contexto da decisão (Fase 4)

Daniel explicitamente aceitou fixtures inferidas com TODO — ver decisão registrada
em `/Users/daniel/.claude/plans/velvety-imagining-gray.md`. A Fase 4 implementou
handlers com base nestes payloads inferidos; a Fase 5 (transparent + disputes)
assume que esta substituição já aconteceu antes de começar.
