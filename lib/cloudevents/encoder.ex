defmodule Cloudevents.Encoder do
  @moduledoc """
  This module converts CloudEvent structs into maps suitable for Avro encoding
  and delegates to Avrora for the actual binary serialization. It handles both
  well-known CloudEvent attributes and extension attributes according to the
  CloudEvents v1.0 specification.

  This module is primarily used internally by `Cloudevents.to_pulsar_message/3`.
  """

  alias Cloudevents.Event

  require Avrora

  @doc """
  Encodes a Cloudevent using Avro binary encoding.
  """
  @spec encode(Event.t(), String.t()) :: {:ok, binary()} | {:error, term()}
  def encode(payload, schema_name) do
    payload
    |> to_map()
    |> Avrora.encode(schema_name: schema_name, format: :guess)
  end

  @spec encode(Event.t(), String.t(), :guess | :registry | :ocf) :: {:ok, binary()} | {:error, term()}
  def encode(payload, schema_name, format) do
    payload
    |> to_map()
    |> Avrora.encode(schema_name: schema_name, format: format)
  end

  defp to_map(%Event{specversion: "1.0", type: type, source: source, id: id} = event) do
    # Build attribute map with all context attributes
    attributes =
      %{
        "specversion" => "1.0",
        "type" => type,
        "source" => source,
        "id" => id
      }
      |> add_attr_if_set(event, :subject)
      |> add_attr_if_set(event, :time)
      |> add_attr_if_set(event, :datacontenttype)
      |> add_attr_if_set(event, :dataschema)

    # Add extension attributes to the attribute map
    extensions = Map.get(event, :extensions, %{})
    all_attributes = Map.merge(attributes, extensions)

    # Build the CloudEvents Avro format: attribute map + data
    %{
      "attribute" => all_attributes,
      "data" => Map.get(event, :data)
    }
  end

  defp add_attr_if_set(dst, src, key) do
    val = Map.get(src, key)
    # Convert atom key to string for attribute map
    if val, do: Map.put(dst, to_string(key), val), else: dst
  end
end
