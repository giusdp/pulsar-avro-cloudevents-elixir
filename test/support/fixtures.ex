defmodule Cloudevents.Test.Fixtures do
  @moduledoc """
  Pre-encoded Avro binaries for testing decoder functionality.
  These fixtures are generated once and reused across tests to avoid
  encoding dependencies in decoder tests.
  """

  alias Cloudevents.Event

  @doc """
  Returns a valid Avro-encoded CloudEvent binary for a UserCreated event.
  """
  def valid_user_created_binary do
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

    {:ok, binary} = Cloudevents.to_pulsar_message(event, "com.example.UserCreated")
    binary
  end

  @doc """
  Returns an invalid Avro binary (not valid Avro encoding).
  """
  def invalid_avro_binary do
    "not valid avro binary"
  end
end
