defmodule Cloudevents.Decoder do
  @moduledoc """
  This module decodes Avro-encoded CloudEvent messages from Apache Pulsar. The entire
  CloudEvent structure (including all context attributes and data fields) must be encoded
  in the message body according to your Avro schema.

  Your Avro schemas must include the CloudEvent required fields (`specversion`, `type`,
  `source`, `id`) along with your domain-specific data fields.

  This module is used internally by `Cloudevents.from_pulsar_message/3`.
  """

  alias Cloudevents.DecodeError
  alias Cloudevents.Event
  alias Cloudevents.ParseError

  require Avrora

  @doc """
  Parses a Pulsar message as a CloudEvent using Avro encoding.

  The message body should contain an Avro-encoded record that includes both CloudEvent
  context attributes and your domain data fields. Uses the embedded Avro schema from the message.

  ## Parameters
  - `pulsar_body` - The Avro-encoded message body with embedded schema
  - `pulsar_headers` - The message headers

  ## Examples

      {:ok, event} = Cloudevents.from_pulsar_message(body, headers)
  """
  @spec decode(binary()) :: {:ok, Event.t()} | {:error, any}
  def decode(pulsar_body) do
    pulsar_body
    |> Avrora.decode()
    |> parse_avro_map()
  end

  @spec decode(binary(), String.t()) :: {:ok, Event.t()} | {:error, any}
  def decode(pulsar_body, schema_name) do
    pulsar_body
    |> Avrora.decode(schema_name)
    |> parse_avro_map()
  end

  defp parse_avro_map(avrora_result) do
    with {:decode, {:ok, avro_map}} <- {:decode, unpack_decoded(avrora_result)},
         {:transform, {:ok, ce_map}} <- {:transform, transform_from_avro_format(avro_map)},
         {:parse, {:ok, event}} <- {:parse, Event.from_map(ce_map)} do
      {:ok, event}
    else
      {:decode, {:error, %MatchError{}}} ->
        {:error, %DecodeError{cause: "Binary does not look like a valid Avro encoding"}}

      {:decode, {:error, {:failed_to_connect, connection_error}}} ->
        {:error,
         %DecodeError{
           cause: "Failed to connect to Confluent Schema Registry: #{inspect(connection_error)}"
         }}

      {:decode, {:error, other_error}} ->
        {:error, %DecodeError{cause: "Failed to decode Avro binary: #{inspect(other_error)}"}}

      {:transform, {:error, reason}} ->
        {:error, %DecodeError{cause: "Failed to transform Avro format: #{inspect(reason)}"}}

      {:parse, {:error, %ParseError{} = error}} ->
        {:error, %DecodeError{cause: error}}
    end
  end

  defp unpack_decoded({:ok, [map]}) when is_map(map), do: {:ok, map}
  defp unpack_decoded({:ok, map}) when is_map(map), do: {:ok, map}
  defp unpack_decoded({:error, error}), do: {:error, error}

  # Transform from CloudEvents Avro format (attribute map + data) to CloudEvent map
  defp transform_from_avro_format(%{"attribute" => attributes, "data" => data}) do
    # Extract all attributes as strings
    ce_map = Map.new(attributes, fn {k, v} -> {to_string(k), v} end)

    # Add data if present
    ce_map =
      if data do
        Map.put(ce_map, "data", data)
      else
        ce_map
      end

    {:ok, ce_map}
  end

  defp transform_from_avro_format(other) do
    {:error, "Invalid CloudEvents Avro format, expected 'attribute' and 'data' fields, got: #{inspect(Map.keys(other))}"}
  end
end
