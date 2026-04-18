require "test_helper"

class Pay::Abacatepay::WebhooksControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  ENDPOINT = "/pay/webhooks/abacatepay"

  setup do
    @fixture = File.read(File.expand_path("../../fixtures/webhooks/subscription_completed.json", __dir__))
  end

  test "valid HMAC + known event returns 200 and invokes the handler" do
    received = []
    callback = ->(_name, _s, _f, _id, payload) { received << payload }

    ActiveSupport::Notifications.subscribed(callback, "pay.abacatepay.subscription.completed") do
      perform_enqueued_jobs do
        post ENDPOINT, params: @fixture, headers: abacatepay_webhook_headers(@fixture)
      end
    end

    assert_response :ok
    assert_equal 1, received.size
    assert_equal "sub_fixture_1", received.first.dig("data", "id")
  end

  test "invalid HMAC returns 401 and nothing is enqueued" do
    headers = {"Content-Type" => "application/json", "X-Webhook-Signature" => "deadbeef"}

    assert_no_enqueued_jobs do
      post ENDPOINT, params: @fixture, headers: headers
    end

    assert_response :unauthorized
    assert_equal 0, Pay::Webhook.where(processor: "abacatepay").count
  end

  test "missing X-Webhook-Signature header returns 401" do
    assert_no_enqueued_jobs do
      post ENDPOINT, params: @fixture, headers: {"Content-Type" => "application/json"}
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

  test "duplicate event is accepted but only queued once" do
    received = 0
    callback = ->(_n, _s, _f, _id, _payload) { received += 1 }

    ActiveSupport::Notifications.subscribed(callback, "pay.abacatepay.subscription.completed") do
      post ENDPOINT, params: @fixture, headers: abacatepay_webhook_headers(@fixture)
      assert_response :ok
      assert_equal 1, Pay::Webhook.where(processor: "abacatepay").count

      post ENDPOINT, params: @fixture, headers: abacatepay_webhook_headers(@fixture)
      assert_response :ok
      assert_equal 1, Pay::Webhook.where(processor: "abacatepay").count

      perform_enqueued_jobs
    end

    assert_equal 1, received
  end

  test "unknown event type is accepted with 200 and ignored" do
    payload = {event: "foo.bar", data: {id: "whatever"}}.to_json

    assert_no_enqueued_jobs do
      post ENDPOINT, params: payload, headers: abacatepay_webhook_headers(payload)
    end

    assert_response :ok
    assert_equal 0, Pay::Webhook.where(processor: "abacatepay").count
  end

  test "helper produces a signature accepted by the controller" do
    headers = abacatepay_webhook_headers(@fixture)

    assert_match(/\A[0-9a-f]{64}\z/, headers["X-Webhook-Signature"])
    post ENDPOINT, params: @fixture, headers: headers
    assert_response :ok
  end
end
