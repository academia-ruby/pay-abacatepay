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
    end
  end
end
