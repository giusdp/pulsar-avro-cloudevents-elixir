defmodule Cloudevents.Event do
  @moduledoc """
  This module represents a CloudEvent v1.0 compliant event structure, defining the structure
  for event data with required and optional context attributes. CloudEvents provides
  a common format for describing events in a vendor-neutral way.

  ## Required Attributes

  - `specversion` - The version of the CloudEvents specification (always "1.0")
  - `type` - The type of the event (e.g., "com.example.user.created")
  - `source` - The context in which the event occurred (e.g., "/users/123")
  - `id` - A unique identifier for the event

  ## Optional Attributes

  - `subject` - The subject of the event in the context of the event source
  - `time` - Timestamp of when the event occurred (RFC3339 format)
  - `datacontenttype` - Content type of the data value (defaults to "application/json")
  - `dataschema` - A link to the schema that the data adheres to
  - `data` - The actual event payload
  - `extensions` - Additional context attributes not defined in the spec

  ## Extension Attributes

  Extension attributes must follow the CloudEvents naming convention:
  - Only lowercase letters ('a' to 'z') and digits ('0' to '9')
  - Should not exceed 20 characters in length

  ## Examples

      # Create a simple event from a map
      {:ok, event} = Event.from_map(%{
        "specversion" => "1.0",
        "type" => "com.example.user.created",
        "source" => "/users",
        "id" => "A234-1234-1234",
        "data" => %{"userId" => "123", "name" => "John Doe"}
      })

      # Create an event using the builder pattern
      {:ok, event} =
        Event.new()
        |> Event.with_type("com.example.user.created")
        |> Event.with_source("/users")
        |> Event.with_id("A234-1234-1234")
        |> Event.with_data(%{"userId" => "123", "name" => "John Doe"})
        |> Event.build()

      # Create an event with auto-generated ID and timestamp
      {:ok, event} =
        Event.new_with_defaults()
        |> Event.with_type("com.example.order.placed")
        |> Event.with_source("/orders")
        |> Event.with_subject("order/789")
        |> Event.with_data(%{"orderId" => "789", "amount" => 100.50})
        |> Event.build()

      # Create an event with extensions using builder pattern
      {:ok, event} =
        Event.new()
        |> Event.with_type("com.example.notification")
        |> Event.with_source("/notifications")
        |> Event.with_id(Event.generate_id())
        |> Event.with_extension("priority", "high")
        |> Event.with_extension("customerid", "456")
        |> Event.build()
  """
  use TypedStruct

  alias Cloudevents.ParseError

  @typedoc @moduledoc
  typedstruct do
    field :specversion, String.t(), default: "1.0"
    field :type, String.t(), enforce: true
    field :source, String.t(), enforce: true
    field :id, String.t(), enforce: true
    field :subject, String.t()
    field :time, String.t()
    field :datacontenttype, String.t()
    field :dataschema, String.t()
    field :data, any
    field :extensions, %{optional(String.t()) => any}
  end

  def from_map(map) when is_map(map) do
    {event_data, ctx_attrs} = Map.pop(map, "data")

    {_, extension_attrs} =
      Map.split(ctx_attrs, [
        "specversion",
        "type",
        "source",
        "id",
        "subject",
        "time",
        "datacontenttype",
        "dataschema",
        "data"
      ])

    with :ok <- parse_specversion(ctx_attrs),
         {:ok, type} <- parse_type(ctx_attrs),
         {:ok, source} <- parse_source(ctx_attrs),
         {:ok, id} <- parse_id(ctx_attrs),
         {:ok, subject} <- parse_subject(ctx_attrs),
         {:ok, time} <- parse_time(ctx_attrs),
         {:ok, datacontenttype} <- parse_datacontenttype(ctx_attrs),
         {:ok, dataschema} <- parse_dataschema(ctx_attrs),
         {:ok, data} <- parse_data(event_data),
         {:ok, extensions} <- validated_extensions_attributes(extension_attrs) do
      datacontenttype =
        if is_nil(datacontenttype) and not is_nil(data),
          do: "application/json",
          else: datacontenttype

      event = %__MODULE__{
        type: type,
        source: source,
        id: id,
        subject: subject,
        time: time,
        datacontenttype: datacontenttype,
        dataschema: dataschema,
        data: data,
        extensions: extensions
      }

      {:ok, event}
    else
      {:error, parse_error} ->
        {:error, %ParseError{message: parse_error}}
    end
  end

  # Builder Pattern Functions
  # ---

  @doc """
  Creates a new CloudEvent builder with an empty state.

  Returns a map that can be progressively populated using `with_*` functions
  and finalized with `build/1`.

  ## Examples

      Event.new()
      |> Event.with_type("com.example.user.created")
      |> Event.with_source("/users")
      |> Event.with_id("123")
      |> Event.build()
  """
  @spec new() :: map()
  def new do
    %{"specversion" => "1.0"}
    |> with_id(generate_id())
    |> with_time(DateTime.utc_now())
  end

  @doc """
  Sets the event type in the builder.

  ## Parameters
  - `builder` - The builder map
  - `type` - The event type (e.g., "com.example.user.created")

  ## Examples

      Event.new() |> Event.with_type("com.example.user.created")
  """
  @spec with_type(map(), String.t()) :: map()
  def with_type(builder, type) when is_map(builder) and is_binary(type) do
    Map.put(builder, "type", type)
  end

  @doc """
  Sets the event source in the builder.

  ## Parameters
  - `builder` - The builder map
  - `source` - The source URI (e.g., "/users/service")

  ## Examples

      Event.new() |> Event.with_source("/users/service")
  """
  @spec with_source(map(), String.t()) :: map()
  def with_source(builder, source) when is_map(builder) and is_binary(source) do
    Map.put(builder, "source", source)
  end

  @doc """
  Sets the event ID in the builder.

  ## Parameters
  - `builder` - The builder map
  - `id` - The event ID (unique identifier)

  ## Examples

      Event.new() |> Event.with_id("user-123")
      Event.new() |> Event.with_id(Event.generate_id())
  """
  @spec with_id(map(), String.t()) :: map()
  def with_id(builder, id) when is_map(builder) and is_binary(id) do
    Map.put(builder, "id", id)
  end

  @doc """
  Sets the optional subject in the builder.

  ## Parameters
  - `builder` - The builder map
  - `subject` - The event subject

  ## Examples

      Event.new() |> Event.with_subject("user/123")
  """
  @spec with_subject(map(), String.t()) :: map()
  def with_subject(builder, subject) when is_map(builder) and is_binary(subject) do
    Map.put(builder, "subject", subject)
  end

  @doc """
  Sets the timestamp in the builder.

  Accepts either a DateTime struct (which will be formatted to ISO8601) or a string.

  ## Parameters
  - `builder` - The builder map
  - `time` - DateTime struct or ISO8601 string

  ## Examples

      Event.new() |> Event.with_time(DateTime.utc_now())
      Event.new() |> Event.with_time("2023-01-01T12:00:00Z")
  """
  @spec with_time(map(), DateTime.t() | String.t()) :: map()
  def with_time(builder, %DateTime{} = datetime) when is_map(builder) do
    Map.put(builder, "time", format_time(datetime))
  end

  def with_time(builder, time) when is_map(builder) and is_binary(time) do
    Map.put(builder, "time", time)
  end

  @doc """
  Sets the data content type in the builder.

  ## Parameters
  - `builder` - The builder map
  - `content_type` - The MIME type (e.g., "application/json")

  ## Examples

      Event.new() |> Event.with_datacontenttype("application/json")
  """
  @spec with_datacontenttype(map(), String.t()) :: map()
  def with_datacontenttype(builder, content_type) when is_map(builder) and is_binary(content_type) do
    Map.put(builder, "datacontenttype", content_type)
  end

  @doc """
  Sets the data schema in the builder.

  ## Parameters
  - `builder` - The builder map
  - `schema` - URI or identifier for the schema

  ## Examples

      Event.new() |> Event.with_dataschema("https://example.com/schema/user.json")
  """
  @spec with_dataschema(map(), String.t()) :: map()
  def with_dataschema(builder, schema) when is_map(builder) and is_binary(schema) do
    Map.put(builder, "dataschema", schema)
  end

  @doc """
  Sets the event data payload in the builder.

  ## Parameters
  - `builder` - The builder map
  - `data` - The event payload (any type)

  ## Examples

      Event.new() |> Event.with_data(%{"userId" => "123", "email" => "test@example.com"})
  """
  @spec with_data(map(), any()) :: map()
  def with_data(builder, data) when is_map(builder) do
    Map.put(builder, "data", data)
  end

  @doc """
  Adds a single extension attribute to the builder.

  Extension attribute names must follow CloudEvents naming conventions:
  - Only lowercase letters ('a' to 'z') and digits ('0' to '9')
  - Should not exceed 20 characters

  ## Parameters
  - `builder` - The builder map
  - `name` - Extension attribute name
  - `value` - Extension attribute value

  ## Examples

      Event.new() |> Event.with_extension("traceid", "abc-123")
  """
  @spec with_extension(map(), String.t(), any()) :: map()
  def with_extension(builder, name, value) when is_map(builder) and is_binary(name) do
    Map.put(builder, name, value)
  end

  @doc """
  Adds multiple extension attributes to the builder.

  ## Parameters
  - `builder` - The builder map
  - `extensions` - Map of extension attributes

  ## Examples

      Event.new()
      |> Event.with_extensions(%{
        "traceid" => "abc-123",
        "priority" => "high"
      })
  """
  @spec with_extensions(map(), map()) :: map()
  def with_extensions(builder, extensions) when is_map(builder) and is_map(extensions) do
    Map.merge(builder, extensions)
  end

  @doc """
  Builds the final CloudEvent struct from the builder state.

  This function validates all fields and returns a result tuple.

  ## Returns
  - `{:ok, event}` if the builder state is valid
  - `{:error, ParseError}` if validation fails

  ## Examples

      {:ok, event} =
        Event.new()
        |> Event.with_type("com.example.user.created")
        |> Event.with_source("/users")
        |> Event.with_id("123")
        |> Event.build()
  """
  @spec build(map()) :: {:ok, t()} | {:error, ParseError.t()}
  def build(builder) when is_map(builder) do
    from_map(builder)
  end

  # Generates a UUID v4 string to use as an event ID.
  defp generate_id do
    # Generate UUID v4 using Elixir's built-in crypto
    <<u0::48, _::4, u1::12, _::2, u2::62>> = :crypto.strong_rand_bytes(16)
    # Set version (4) and variant (2) bits
    uuid_to_string(<<u0::48, 4::4, u1::12, 2::2, u2::62>>)
  end

  # Convert binary UUID to string format
  defp uuid_to_string(
         <<a1::4, a2::4, a3::4, a4::4, a5::4, a6::4, a7::4, a8::4, b1::4, b2::4, b3::4, b4::4, c1::4, c2::4, c3::4, c4::4,
           d1::4, d2::4, d3::4, d4::4, e1::4, e2::4, e3::4, e4::4, e5::4, e6::4, e7::4, e8::4, e9::4, e10::4, e11::4,
           e12::4>>
       ) do
    <<to_hex(a1), to_hex(a2), to_hex(a3), to_hex(a4), to_hex(a5), to_hex(a6), to_hex(a7), to_hex(a8), ?-, to_hex(b1),
      to_hex(b2), to_hex(b3), to_hex(b4), ?-, to_hex(c1), to_hex(c2), to_hex(c3), to_hex(c4), ?-, to_hex(d1), to_hex(d2),
      to_hex(d3), to_hex(d4), ?-, to_hex(e1), to_hex(e2), to_hex(e3), to_hex(e4), to_hex(e5), to_hex(e6), to_hex(e7),
      to_hex(e8), to_hex(e9), to_hex(e10), to_hex(e11), to_hex(e12)>>
  end

  defp to_hex(n) when n < 10, do: ?0 + n
  defp to_hex(n), do: ?a + n - 10

  @doc """
  Formats a DateTime struct to ISO8601 format for CloudEvents.

  ## Parameters
  - `datetime` - The DateTime struct to format

  ## Examples

      time_str = Event.format_time(DateTime.utc_now())
  """
  @spec format_time(DateTime.t()) :: String.t()
  def format_time(%DateTime{} = datetime) do
    DateTime.to_iso8601(datetime)
  end

  # ---

  defp parse_specversion(%{"specversion" => "1.0"}), do: :ok
  defp parse_specversion(%{"specversion" => x}), do: {:error, "unexpected specversion #{x}"}
  defp parse_specversion(_), do: {:error, "missing specversion"}

  defp parse_type(%{"type" => type}) when byte_size(type) > 0, do: {:ok, type}
  defp parse_type(_), do: {:error, "missing type"}

  defp parse_source(%{"source" => source}) when byte_size(source) > 0, do: {:ok, source}
  defp parse_source(_), do: {:error, "missing source"}

  defp parse_id(%{"id" => id}) when byte_size(id) > 0, do: {:ok, id}
  defp parse_id(_), do: {:error, "missing id"}

  defp parse_subject(%{"subject" => sub}) when byte_size(sub) > 0, do: {:ok, sub}
  defp parse_subject(%{"subject" => ""}), do: {:error, "subject given but empty"}
  defp parse_subject(_), do: {:ok, nil}

  defp parse_time(%{"time" => time}) when byte_size(time) > 0, do: {:ok, time}
  defp parse_time(%{"time" => ""}), do: {:error, "time given but empty"}
  defp parse_time(_), do: {:ok, nil}

  defp parse_datacontenttype(%{"datacontenttype" => ct}) when byte_size(ct) > 0, do: {:ok, ct}

  defp parse_datacontenttype(%{"datacontenttype" => ""}), do: {:error, "datacontenttype given but empty"}

  defp parse_datacontenttype(_), do: {:ok, nil}

  defp parse_dataschema(%{"dataschema" => schema}) when byte_size(schema) > 0, do: {:ok, schema}

  defp parse_dataschema(%{"dataschema" => ""}), do: {:error, "dataschema given but empty"}

  defp parse_dataschema(_), do: {:ok, nil}

  defp parse_data(""), do: {:error, "data field given but empty"}
  defp parse_data(data), do: {:ok, data}

  # ---

  defp try_decode(key, val) when is_binary(val) do
    case JSON.decode(val) do
      {:ok, val_map} ->
        {key, val_map}

      _ ->
        {key, val}
    end
  end

  defp try_decode(key, val), do: {key, val}

  # ---

  defp validated_extensions_attributes(extension_attrs) do
    invalid =
      extension_attrs
      |> Map.keys()
      |> Enum.map(fn key -> {key, valid_extension_attribute_name(key)} end)
      |> Enum.filter(fn {_, valid?} -> not valid? end)

    case invalid do
      [] ->
        extensions = Map.new(extension_attrs, fn {key, val} -> try_decode(key, val) end)
        {:ok, extensions}

      _ ->
        {:error, "invalid extension attributes: #{Enum.map(invalid, fn {key, _} -> inspect(key) end)}"}
    end
  end

  # ---

  defp valid_extension_attribute_name(name) do
    # Cloudevents attribute names MUST consist of lower-case letters ('a' to 'z') or
    # digits ('0' to '9') from the ASCII character set. Attribute names SHOULD be
    # descriptive and terse and SHOULD NOT exceed 20 characters in length.
    # https://github.com/cloudevents/spec/blob/v1.0/spec.md#attribute-naming-convention
    name =~ ~r/^[a-z0-9]+$/
  end
end
