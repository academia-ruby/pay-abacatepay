# VCR config for the gem test suite.
#
# Cassetes ficam em test/vcr_cassettes/. Replay puro por default; para regravar
# contra o sandbox real, defina VCR_RECORD_MODE=all (ou =new_episodes para
# adicionar interações sem regravar as existentes).
#
# Filtros agressivos garantem que NENHUM segredo (api_key, webhook_secret,
# CPF, e-mail real do operador) seja gravado nas cassetes commitadas. Os
# IDs gerados pelo AbacatePay (cust_*, prod_*, bill_/chk_*) NÃO são tratados
# como sensíveis — são opacos e seguros para serem versionados.
#
# Para gravar novas cassetes:
#
#   ABACATEPAY_API_KEY=abc_dev_xxxxxxxxxxxx \
#   ABACATEPAY_WEBHOOK_SECRET=wsec_xxxxxxxx \
#   VCR_RECORD_MODE=all \
#   bundle exec rake test TEST=test/pay/abacatepay/customer_test.rb

require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = File.expand_path("../vcr_cassettes", __dir__)
  config.hook_into :webmock
  config.allow_http_connections_when_no_cassette = false

  config.default_cassette_options = {
    record: ENV.fetch("VCR_RECORD_MODE", "none").to_sym,
    match_requests_on: [:method, :uri, :body],
    decode_compressed_response: true
  }

  # ── Credenciais ──────────────────────────────────────────────────────────
  # Filtramos via callback (não filter_sensitive_data direto) porque o token
  # vem dentro de um header "Authorization: Bearer <token>" e queremos
  # preservar o prefixo "Bearer " na cassette.
  config.before_record do |interaction|
    if (auth = interaction.request.headers["Authorization"])
      interaction.request.headers["Authorization"] = auth.map do |val|
        val.sub(/Bearer\s+\S+/, "Bearer <ABACATEPAY_API_KEY>")
      end
    end
  end

  # Substitui o token literal no body de qualquer request/response (caso a
  # API ecoe o token em algum payload de erro).
  config.filter_sensitive_data("<ABACATEPAY_API_KEY>") do
    ENV["ABACATEPAY_API_KEY"].to_s.empty? ? nil : ENV["ABACATEPAY_API_KEY"]
  end

  config.filter_sensitive_data("<ABACATEPAY_WEBHOOK_SECRET>") do
    ENV["ABACATEPAY_WEBHOOK_SECRET"].to_s.empty? ? nil : ENV["ABACATEPAY_WEBHOOK_SECRET"]
  end

  # ── PII do operador / sandbox ────────────────────────────────────────────
  # AbacatePay é IDEMPOTENTE por taxId: se o CPF usado no teste já foi
  # cadastrado por outro fluxo (ex: E2E manual), o sandbox responde com o
  # customer existente — vazando email/nome/telefone reais na response body.
  # Filtramos defensivamente qualquer e-mail @invenio.dev.br ou nomes/telefones
  # conhecidos do operador. Os filtros são aplicados ANTES de a cassette ser
  # gravada em disco.
  config.before_record do |interaction|
    bodies = [interaction.request.body, interaction.response.body].compact

    bodies.each do |body|
      next unless body.is_a?(String)

      # Qualquer email com domínio do operador → placeholder
      body.gsub!(/[A-Za-z0-9._-]+@invenio\.dev\.br/, "operator@example.com")
      # Telefone real do operador (visto vazar na cassette)
      body.gsub!("11999999999", "00000000000")
      # Nome cadastrado no sandbox para o user de teste
      body.gsub!("Teste AbacatePay", "Test User")
      body.gsub!("Daniel Moreira", "Test User")
    end
  end

  # Filtros opt-in via ENV — útil quando se grava com dados sensíveis em outras situações
  if (real_email = ENV["VCR_FILTER_EMAIL"])
    config.filter_sensitive_data("<FILTERED_EMAIL>") { real_email }
  end
  if (real_cpf = ENV["VCR_FILTER_CPF"])
    config.filter_sensitive_data("<FILTERED_CPF>") { real_cpf }
  end
  if (real_phone = ENV["VCR_FILTER_PHONE"])
    config.filter_sensitive_data("<FILTERED_PHONE>") { real_phone }
  end
end

# VCR fica DESLIGADO por default (turn_off! ignore_cassettes: true), para que
# os testes legados que usam WebMock.stub_request continuem funcionando sem
# alteração. Quando um teste chama `with_cassette`, VCR é ligado pelo escopo
# do bloco e desligado de novo no ensure.
#
# Isto evita o conflito clássico VCR↔WebMock: com `hook_into :webmock` e
# `allow_http_connections_when_no_cassette = false`, qualquer request fora
# de cassette resulta em VCR error — bloqueando até stubs WebMock válidos.
module VCRTestHelper
  def with_cassette(name, **opts, &block)
    VCR.turn_on!
    VCR.use_cassette(name, **opts, &block)
  ensure
    VCR.turn_off!(ignore_cassettes: true)
  end
end

ActiveSupport::TestCase.include(VCRTestHelper)

VCR.turn_off!(ignore_cassettes: true)
