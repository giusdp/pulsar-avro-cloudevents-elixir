defmodule Cloudevents.IntegrationTest do
  use ExUnit.Case, async: true

  alias Cloudevents.Event

  describe "encode/decode with to_pulsar_message/2" do
    test "encodes and decodes CloudEvent with domain data" do
      {:ok, event} =
        Event.from_map(%{
          "specversion" => "1.0",
          "type" => "com.example.user.created",
          "source" => "/users/service",
          "id" => "user-123",
          "data" => %{
            "userid" => "456",
            "email" => "test@example.com",
            "createdat" => 1_640_000_000_000
          }
        })

      schema_name = "com.example.UserCreated"

      {:ok, body} = Cloudevents.to_pulsar_message(event, schema_name)
      {:ok, event_from_body} = Cloudevents.from_pulsar_message(body)

      assert event_from_body.specversion == "1.0"
      assert event_from_body.type == "com.example.user.created"
      assert event_from_body.source == "/users/service"
      assert event_from_body.id == "user-123"
      assert event_from_body.data["userid"] == "456"
      assert event_from_body.data["email"] == "test@example.com"
      assert event_from_body.data["createdat"] == 1_640_000_000_000
    end
  end

  describe "encode/decode roundtrip with bang variants" do
    test "successful roundtrip with bang variant for encoder" do
      {:ok, event} =
        Event.from_map(%{
          "specversion" => "1.0",
          "type" => "com.example.user.created",
          "source" => "/test",
          "id" => "123",
          "data" => %{
            "userid" => "999",
            "email" => "roundtrip@example.com",
            "createdat" => 1_640_000_000_000
          }
        })

      body = Cloudevents.to_pulsar_message!(event, "com.example.UserCreated")
      decoded_event = Cloudevents.from_pulsar_message!(body)

      assert decoded_event.type == event.type
      assert decoded_event.source == event.source
      assert decoded_event.id == event.id
      assert decoded_event.data == event.data
    end
  end
end
