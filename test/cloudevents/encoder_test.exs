defmodule Cloudevents.EncoderTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Cloudevents.Event

  describe "to_pulsar_message/2" do
    test "encodes CloudEvent with domain data successfully" do
      {:ok, event} =
        Event.from_map(%{
          "specversion" => "1.0",
          "type" => "com.example.user.created",
          "source" => "/users/service",
          "id" => "id-123",
          "data" => %{
            "userid" => "456",
            "email" => "test@example.com",
            "createdat" => 1_640_000_000_000
          }
        })

      schema_name = "com.example.UserCreated"

      assert {:ok, body} = Cloudevents.to_pulsar_message(event, schema_name)
      assert is_binary(body)
      assert byte_size(body) > 0
    end

    test "encoding with non-existent schema returns error" do
      {:ok, event} =
        Event.from_map(%{
          "specversion" => "1.0",
          "type" => "com.example.test",
          "source" => "/test",
          "id" => "123",
          "data" => %{"key" => "value"}
        })

      assert {:error, :enoent} = Cloudevents.to_pulsar_message(event, "nonexistent.Schema")
    end

    test "encoding with mismatched data returns error" do
      {:ok, event} =
        Event.from_map(%{
          "specversion" => "1.0",
          "type" => "com.example.test",
          "source" => "/test",
          "id" => "123",
          "data" => %{"wrong_field" => "value"}
        })

      assert {:error, _error_message} =
               Cloudevents.to_pulsar_message(event, "foo.Bar")
    end
  end

  describe "to_pulsar_message!/2 bang variant" do
    test "returns binary directly on success" do
      {:ok, event} =
        Event.from_map(%{
          "specversion" => "1.0",
          "type" => "com.example.user.created",
          "source" => "/test",
          "id" => "123",
          "data" => %{
            "userid" => "789",
            "email" => "bang@example.com",
            "createdat" => 1_640_000_000_000
          }
        })

      body = Cloudevents.to_pulsar_message!(event, "com.example.UserCreated")

      assert is_binary(body)
      assert byte_size(body) > 0
    end

    test "raises ArgumentError on encoding failure" do
      {:ok, event} =
        Event.from_map(%{
          "specversion" => "1.0",
          "type" => "com.example.test",
          "source" => "/test",
          "id" => "123",
          "data" => %{"wrong_field" => "value"}
        })

      assert_raise ArgumentError, fn ->
        Cloudevents.to_pulsar_message!(event, "foo.Bar")
      end
    end
  end
end
