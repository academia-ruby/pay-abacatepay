require "test_helper"

class Pay::Abacatepay::WebhooksControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  ENDPOINT = "/pay/webhooks/abacatepay"
  FIXTURES = File.expand_path("../../fixtures/webhooks", __dir__)

  def fixture(name)
    File.read(File.join(FIXTURES, "#{name}.json"))
  end

  setup do
    @completed = fixture("subscription_completed")
    @renewed = fixture("subscription_renewed")
    @user = User.create!(email: "ctrl@example.com", name: "Ctrl", document: "111.222.333-44")
    @pay_customer = Pay::Customer.create!(owner: @user, processor: "abacatepay", processor_id: "cust_def456")
  end

  test "valid HMAC + known event returns 200 and invokes the handler" do
    received = []
    callback = ->(_name, _s, _f, _id, payload) { received << payload }

    ActiveSupport::Notifications.subscribed(callback, "pay.abacatepay.subscription.completed") do
      perform_enqueued_jobs do
        post ENDPOINT, params: @completed, headers: abacatepay_webhook_headers(@completed)
      end
    end

    assert_response :ok
    assert_equal 1, received.size
    assert_equal "log_completed_abc123", received.first["id"]
  end

  test "invalid HMAC returns 401 and nothing is enqueued" do
    headers = {"Content-Type" => "application/json", "X-Webhook-Signature" => "deadbeef"}

    assert_no_enqueued_jobs do
      post ENDPOINT, params: @completed, headers: headers
    end

    assert_response :unauthorized
    assert_equal 0, Pay::Webhook.where(processor: "abacatepay").count
  end

  test "missing X-Webhook-Signature header AND no body secret returns 401" do
    assert_no_enqueued_jobs do
      post ENDPOINT, params: @completed, headers: {"Content-Type" => "application/json"}
    end

    assert_response :unauthorized
    assert_equal 0, Pay::Webhook.where(processor: "abacatepay").count
  end

  test "webhookSecret query parameter (official scheme) returns 200 when matching" do
    post "#{ENDPOINT}?webhookSecret=#{ENV["ABACATEPAY_WEBHOOK_SECRET"]}",
      params: @completed,
      headers: {"Content-Type" => "application/json"}

    assert_response :ok
    assert_equal 1, Pay::Webhook.where(processor: "abacatepay").count
  end

  test "webhookSecret query parameter that does NOT match returns 401" do
    assert_no_enqueued_jobs do
      post "#{ENDPOINT}?webhookSecret=wrong-value",
        params: @completed,
        headers: {"Content-Type" => "application/json"}
    end

    assert_response :unauthorized
    assert_equal 0, Pay::Webhook.where(processor: "abacatepay").count
  end

  test "plaintext webhookSecret in body (sandbox-style) returns 200 when matching" do
    payload = JSON.parse(@completed).merge("webhookSecret" => ENV["ABACATEPAY_WEBHOOK_SECRET"]).to_json

    post ENDPOINT, params: payload, headers: {"Content-Type" => "application/json"}

    assert_response :ok
    assert_equal 1, Pay::Webhook.where(processor: "abacatepay").count
  end

  test "plaintext webhookSecret in body that does NOT match returns 401" do
    payload = JSON.parse(@completed).merge("webhookSecret" => "wrong-secret").to_json

    assert_no_enqueued_jobs do
      post ENDPOINT, params: payload, headers: {"Content-Type" => "application/json"}
    end

    assert_response :unauthorized
    assert_equal 0, Pay::Webhook.where(processor: "abacatepay").count
  end

  test "malformed JSON with valid HMAC returns 400" do
    broken = "{nope"

    assert_no_enqueued_jobs do
      post ENDPOINT, params: broken, headers: abacatepay_webhook_headers(broken)
    end

    assert_response :bad_request
    assert_equal 0, Pay::Webhook.where(processor: "abacatepay").count
  end

  test "duplicate event within the ephemeral Pay::Webhook window is queued once" do
    post ENDPOINT, params: @completed, headers: abacatepay_webhook_headers(@completed)
    assert_response :ok
    assert_equal 1, Pay::Webhook.where(processor: "abacatepay").count

    post ENDPOINT, params: @completed, headers: abacatepay_webhook_headers(@completed)
    assert_response :ok
    assert_equal 1, Pay::Webhook.where(processor: "abacatepay").count
  end

  test "unknown event type is accepted with 200 and ignored" do
    payload = {event: "foo.bar", id: "log_unknown", data: {id: "whatever"}}.to_json

    assert_no_enqueued_jobs do
      post ENDPOINT, params: payload, headers: abacatepay_webhook_headers(payload)
    end

    assert_response :ok
    assert_equal 0, Pay::Webhook.where(processor: "abacatepay").count
  end

  test "helper produces a signature accepted by the controller" do
    headers = abacatepay_webhook_headers(@completed)

    assert_match(%r{\A[A-Za-z0-9+/]+={0,2}\z}, headers["X-Webhook-Signature"])
    post ENDPOINT, params: @completed, headers: headers
    assert_response :ok
  end

  test "end-to-end: valid completed webhook creates Pay::Subscription and Pay::Charge" do
    perform_enqueued_jobs do
      post ENDPOINT, params: @completed, headers: abacatepay_webhook_headers(@completed)
    end

    assert_response :ok

    subscription = @pay_customer.subscriptions.find_by!(processor_id: "subs_tAFqDWBhcEYTjQh2K0ZYDHau")
    charge = @pay_customer.charges.find_by!(processor_id: "char_first789")

    assert_equal "active", subscription.status
    assert_equal 2990, charge.amount
  end

  test "CRITICAL: retry after ACK does not duplicate Pay::Charge (permanent dedup)" do
    # First delivery — goes through Pay::Webhook (ephemeral), handler processes,
    # Pay::Webhook record is destroyed.
    perform_enqueued_jobs do
      post ENDPOINT, params: @renewed, headers: abacatepay_webhook_headers(@renewed)
    end
    assert_response :ok

    # Precondition: charge exists, Pay::Webhook record cleaned up, ProcessedWebhook has entry.
    assert_equal 1, Pay::Charge.where(processor_id: "char_xyz789").count
    assert_equal 0, Pay::Webhook.where(processor: "abacatepay").count
    assert_equal 1, Pay::Abacatepay::ProcessedWebhook.where(event_id: "log_abc123xyz").count

    # Second delivery — simulates AbacatePay retry after we ACKed.
    # Controller dedup (which scans Pay::Webhook) cannot catch it because the record was destroyed.
    # ProcessedWebhook is the safety net.
    perform_enqueued_jobs do
      post ENDPOINT, params: @renewed, headers: abacatepay_webhook_headers(@renewed)
    end
    assert_response :ok

    # MRR is NOT double-counted.
    assert_equal 1, Pay::Charge.where(processor_id: "char_xyz789").count
    assert_equal 1, Pay::Abacatepay::ProcessedWebhook.where(event_id: "log_abc123xyz").count
  end

  test "out-of-order renewed before completed creates subscription on-the-fly" do
    perform_enqueued_jobs do
      post ENDPOINT, params: @renewed, headers: abacatepay_webhook_headers(@renewed)
    end
    assert_response :ok

    subscription = Pay::Abacatepay::Subscription.find_by!(processor_id: "subs_tAFqDWBhcEYTjQh2K0ZYDHau")
    assert_equal "active", subscription.status
    assert_equal 1, Pay::Charge.where(processor_id: "char_xyz789").count
  end
end
