defmodule Cloudevents do
  @moduledoc false

  alias Cloudevents.Event

  @doc """
  Parses a Pulsar message as a Cloudevent using Avro encoding.

  The message body should contain an Avro-encoded record that includes both CloudEvent
  context attributes (specversion, type, source, id) and your domain-specific data fields.
  Uses the embedded Avro schema from the message.

  ## Parameters
  - `pulsar_body` - The Pulsar message body (Avro-encoded binary with embedded schema)

  ## Examples

      {:ok, event} = Cloudevents.from_pulsar_message(body)
  """
  @spec from_pulsar_message(binary()) :: {:ok, Event.t()} | {:error, any}
  defdelegate from_pulsar_message(pulsar_body), to: Cloudevents.Decoder, as: :decode

  @spec from_pulsar_message(binary(), String.t()) :: {:ok, Event.t()} | {:error, any}
  defdelegate from_pulsar_message(pulsar_body, schema_name), to: Cloudevents.Decoder, as: :decode

  @doc """
  Same as `from_pulsar_message/2` but raises on error.

  ## Examples

      event = Cloudevents.from_pulsar_message!(body, headers)
  """
  @spec from_pulsar_message!(binary()) :: Event.t()
  def from_pulsar_message!(pulsar_body) do
    case from_pulsar_message(pulsar_body) do
      {:ok, event} -> event
      {:error, error} -> raise error
    end
  end

  @doc """
  Encodes a CloudEvent to a Pulsar message using Avro encoding.

  The entire CloudEvent structure (including all context attributes and domain data fields)
  is encoded as a single Avro binary in the message body.

  ## Parameters
  - `event` - The CloudEvent to encode
  - `schema_name` - The Avro schema name (should include CloudEvent fields + your domain fields)

  ## Examples

      {:ok, body} = Cloudevents.to_pulsar_message(
        event,
        "com.example.UserCreated"
      )

      # Use different schemas for different event types
      {:ok, body} = Cloudevents.to_pulsar_message(
        payment_event,
        "com.example.PaymentProcessed"
      )
  """
  @spec to_pulsar_message(Event.t(), String.t()) :: {:ok, binary()} | {:error, term()}
  defdelegate to_pulsar_message(event, schema_name), to: Cloudevents.Encoder, as: :encode

  @spec to_pulsar_message(Event.t(), String.t(), :guess | :registry | :ocf) :: {:ok, binary()} | {:error, term()}
  defdelegate to_pulsar_message(event, schema_name, format), to: Cloudevents.Encoder, as: :encode

  @doc """
  Same as `to_pulsar_message/2` but raises on error.

  ## Examples

      {body, headers} = Cloudevents.to_pulsar_message!(
        event,
        "com.example.UserCreated"
      )
  """
  @spec to_pulsar_message!(Event.t(), schema_name :: String.t()) :: binary()
  def to_pulsar_message!(event, schema_name) when is_binary(schema_name) do
    case to_pulsar_message(event, schema_name) do
      {:ok, result} -> result
      {:error, error} -> raise ArgumentError, message: error
    end
  end
end
