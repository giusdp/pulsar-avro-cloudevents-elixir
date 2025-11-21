defmodule Cloudevents.DecoderTest do
  @moduledoc false
  use ExUnit.Case

  alias Cloudevents.Test.Fixtures

  describe "from_pulsar_message/1" do
    test "decodes valid Avro-encoded CloudEvent" do
      binary = Fixtures.valid_user_created_binary()

      assert {:ok, decoded} = Cloudevents.from_pulsar_message(binary)
      assert decoded.specversion == "1.0"
      assert decoded.type == "com.example.user.created"
      assert decoded.source == "/users/service"
      assert decoded.id == "user-123"
      assert decoded.data["userid"] == "456"
      assert decoded.data["email"] == "test@example.com"
      assert decoded.data["createdat"] == 1_640_000_000_000
    end

    test "decoding with invalid Avro binary returns error" do
      invalid_body = Fixtures.invalid_avro_binary()

      assert {:error, error} = Cloudevents.from_pulsar_message(invalid_body)
      assert is_struct(error, Cloudevents.DecodeError)
      assert error.cause =~ "Failed to decode Avro binary"
    end
  end

  describe "from_pulsar_message!/1 bang variant" do
    test "returns decoded event on success" do
      binary = Fixtures.valid_user_created_binary()

      decoded = Cloudevents.from_pulsar_message!(binary)

      assert decoded.type == "com.example.user.created"
      assert decoded.data["userid"] == "456"
    end

    test "raises DecodeError on decoding failure" do
      invalid_body = Fixtures.invalid_avro_binary()

      assert_raise Cloudevents.DecodeError, fn ->
        Cloudevents.from_pulsar_message!(invalid_body)
      end
    end
  end
end
