require "test_helper"

module Pay
  module Abacatepay
    class CustomerTest < ActiveSupport::TestCase
      CREATE_URL = "https://api.abacatepay.com/v2/customers/create"
      GET_URL = "https://api.abacatepay.com/v2/customers/get"

      setup do
        @user = User.create!(
          email: "daniel@invenio.dev.br",
          name: "Daniel Moreira",
          document: "123.456.789-01"
        )
      end

      test "creates a new customer on the API and stores processor_id" do
        stub = stub_request(:post, CREATE_URL)
          .with(
            headers: {"Authorization" => "Bearer abc_dev_test_token"},
            body: hash_including("email" => "daniel@invenio.dev.br", "taxId" => "12345678901")
          )
          .to_return(
            status: 200,
            headers: {"Content-Type" => "application/json"},
            body: {
              data: {
                id: "cust_abc123",
                metadata: {
                  name: "Daniel Moreira",
                  email: "daniel@invenio.dev.br",
                  taxId: "12345678901"
                }
              }
            }.to_json
          )

        result = @user.payment_processor.api_record

        assert_equal "cust_abc123", result.id
        assert_equal "cust_abc123", @user.payment_processor.reload.processor_id
        assert_requested stub
      end

      test "retrieves existing customer when processor_id already set" do
        @user.payment_processor.update!(processor_id: "cust_existing")

        create_stub = stub_request(:post, CREATE_URL)
        get_stub = stub_request(:get, /#{Regexp.escape(GET_URL)}/o)
          .to_return(
            status: 200,
            headers: {"Content-Type" => "application/json"},
            body: {data: {id: "cust_existing", metadata: {email: "daniel@invenio.dev.br"}}}.to_json
          )

        result = @user.payment_processor.api_record

        assert_equal "cust_existing", result.id
        assert_not_requested create_stub
        assert_requested get_stub
      end

      test "is idempotent on duplicate taxId (API returns existing customer)" do
        stub_request(:post, CREATE_URL)
          .to_return(
            status: 200,
            headers: {"Content-Type" => "application/json"},
            body: {data: {id: "cust_preexisting", metadata: {email: "daniel@invenio.dev.br"}}}.to_json
          )

        result = @user.payment_processor.api_record

        assert_equal "cust_preexisting", result.id
        assert_equal "cust_preexisting", @user.payment_processor.reload.processor_id
      end

      test "raises Pay::Abacatepay::Error when owner has no document method" do
        user = UndocumentedUser.create!(email: "x@y.com", name: "X")

        assert_raises(Pay::Abacatepay::Error) { user.payment_processor.api_record }
      end

      test "raises Pay::Abacatepay::Error when document is blank" do
        @user.update!(document: "")

        assert_raises(Pay::Abacatepay::Error) { @user.payment_processor.api_record }
      end

      test "wraps SDK ApiError in Pay::Abacatepay::Error" do
        stub_request(:post, CREATE_URL)
          .to_return(
            status: 400,
            headers: {"Content-Type" => "application/json"},
            body: {error: "invalid email"}.to_json
          )

        assert_raises(Pay::Abacatepay::Error) { @user.payment_processor.api_record }
      end

      test "update_api_record is a no-op that does not hit the API" do
        @user.payment_processor.update!(processor_id: "cust_noupdate")
        stub = stub_request(:any, /api\.abacatepay\.com/)

        result = @user.payment_processor.update_api_record(name: "New Name")

        assert_nil result
        assert_not_requested stub
      end

      test "falls back to cpf when document is not defined" do
        user = CpfUser.create!(email: "cpf@example.com", name: "CPF User")

        stub = stub_request(:post, CREATE_URL)
          .with(body: hash_including("taxId" => "98765432100"))
          .to_return(
            status: 200,
            headers: {"Content-Type" => "application/json"},
            body: {data: {id: "cust_cpf", metadata: {}}}.to_json
          )

        user.payment_processor.api_record
        assert_requested stub
      end

      # Customer#charge (hosted checkout) — Fase 4

      CHECKOUT_CREATE_URL = "https://api.abacatepay.com/v2/checkouts/create"
      PRODUCT_CREATE_URL = "https://api.abacatepay.com/v2/products/create"

      def stub_product_create(product_id: "prod_generated")
        stub_request(:post, PRODUCT_CREATE_URL)
          .to_return(
            status: 200,
            headers: {"Content-Type" => "application/json"},
            body: {data: {id: product_id, externalId: "pay-abacatepay-xxx", name: "Cobrança avulsa", price: 5000, currency: "BRL"}}.to_json
          )
      end

      def stub_checkout_create(id: "chk_new1", url: "https://app.abacatepay.com/pay/chk_new1")
        stub_request(:post, CHECKOUT_CREATE_URL)
          .to_return(
            status: 200,
            headers: {"Content-Type" => "application/json"},
            body: {
              data: {
                id: id,
                url: url,
                amount: 5000,
                status: "PENDING",
                frequency: "ONE_TIME",
                methods: ["PIX", "CARD"],
                customer: {id: "cust_charge1"}
              }
            }.to_json
          )
      end

      test "#charge creates product on-the-fly when product_id is absent and returns struct with pending charge" do
        @user.payment_processor.update!(processor_id: "cust_charge1")
        product_stub = stub_product_create(product_id: "prod_generated")
        checkout_stub = stub_checkout_create

        result = @user.payment_processor.charge(5000)

        assert_requested product_stub
        assert_requested checkout_stub
        assert_equal "chk_new1", result.id
        assert_equal "https://app.abacatepay.com/pay/chk_new1", result.url
        assert_instance_of Pay::Abacatepay::Charge, result.charge
        assert_equal "pending", result.charge.status
        assert_equal 5000, result.charge.amount
        assert_equal "BRL", result.charge.currency
        assert_equal "chk_new1", result.charge.processor_id
        assert_equal "Pay::Abacatepay::Charge", Pay::Charge.last.type
      end

      test "#charge skips product creation when product_id is provided" do
        @user.payment_processor.update!(processor_id: "cust_charge1")
        product_stub = stub_product_create
        checkout_stub = stub_checkout_create

        @user.payment_processor.charge(5000, product_id: "prod_existing")

        assert_not_requested product_stub
        assert_requested checkout_stub
      end

      test "#charge is idempotent on duplicate checkout id (find_or_initialize)" do
        @user.payment_processor.update!(processor_id: "cust_charge1")
        stub_product_create
        stub_checkout_create(id: "chk_dup")

        first = @user.payment_processor.charge(5000)
        stub_product_create
        stub_checkout_create(id: "chk_dup")
        second = @user.payment_processor.charge(5000)

        assert_equal first.charge.id, second.charge.id
        assert_equal 1, Pay::Abacatepay::Charge.where(processor_id: "chk_dup").count
      end

      test "#charge wraps SDK errors in Pay::Abacatepay::Error" do
        @user.payment_processor.update!(processor_id: "cust_charge1")
        stub_request(:post, PRODUCT_CREATE_URL)
          .to_return(status: 500, body: {error: "boom"}.to_json, headers: {"Content-Type" => "application/json"})

        assert_raises(Pay::Abacatepay::Error) { @user.payment_processor.charge(5000) }
      end

      test "#charge creates customer via api_record when processor_id is absent" do
        create_stub = stub_request(:post, CREATE_URL)
          .to_return(
            status: 200,
            headers: {"Content-Type" => "application/json"},
            body: {data: {id: "cust_autogen", metadata: {email: "daniel@invenio.dev.br"}}}.to_json
          )
        stub_product_create
        stub_checkout_create

        @user.payment_processor.charge(5000)

        assert_requested create_stub
        assert_equal "cust_autogen", @user.payment_processor.reload.processor_id
      end
    end
  end
end
