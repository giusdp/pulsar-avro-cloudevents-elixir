<span id="badges">

[![Apache 2.0 license](https://img.shields.io/hexpm/l/cloudevents.svg?style=flat-square)](./LICENSE)

</span>

# Pulsar Avro CloudEvents

An Elixir library for working with [CloudEvents] v1.0 on Apache Pulsar using Apache Avro encoding. This library provides automatic Avro schema management with optional Confluent Schema Registry support,. Based on [avrora](https://github.com/Strech/avrora).

[CloudEvents]: https://cloudevents.io/

<div id="status">

## Supported versions

* OTP 27.0 and later
* Elixir 1.18 and later

</div>

## Installation

Add `pulsar_avro_cloudevents` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pulsar_avro_cloudevents, git: "https://github.com/giusdp/pulsar-avro-cloudevents-elixir"}
  ]
end
```

## Quick Start

This example shows how to use the library with local Avro schemas.

### 1. Create your Avro schemas

**IMPORTANT:** Avro schemas should follow the [CloudEvents Avro format specification](https://github.com/cloudevents/spec/blob/main/cloudevents/formats/avro-format.md):
- An `attribute` field (map) containing all CloudEvent context attributes and extensions
- A `data` field (union type) containing your domain-specific payload

Create your `.avsc` schema files in a directory like `priv/schemas`:

`priv/schemas/com/example/UserCreated.avsc`:
```json
{
  "type": "record",
  "namespace": "com.example",
  "name": "UserCreated",
  "doc": "CloudEvent for user creation",
  "fields": [
    {
      "name": "attribute",
      "type": {
        "type": "map",
        "values": ["null", "boolean", "int", "string", "bytes"]
      },
      "doc": "CloudEvent context attributes (specversion, type, source, id, etc.)"
    },
    {
      "name": "data",
      "type": [
        "null",
        {
          "type": "record",
          "name": "UserCreatedData",
          "fields": [
            { "name": "userid", "type": "string" },
            { "name": "email", "type": "string" },
            { "name": "createdat", "type": "long" }
          ]
        }
      ],
      "doc": "Domain-specific user data"
    }
  ]
}
```

### 2. Configure and use in your code

Now you can use the library to encode and decode CloudEvents. Ensure you have configured your `pulsar_avro_cloudevents` application in your `config/config.exs` file (see the "Configuration" section for more details). For local schemas, your configuration might look like this:

```elixir
# config/config.exs
config :pulsar_avro_cloudevents,
  schemas_path: Path.expand("../priv/schemas", __DIR__)
```

Then, the following can be run in `iex -S mix`:

```elixir
alias Cloudevents.Event

# 1. Create a CloudEvent using the builder pattern (idiomatic Elixir with pipes)
{:ok, event} =
  Event.new()
  |> Event.with_type("com.example.user.created")
  |> Event.with_source("/users/service")
  |> Event.with_data(%{
    "userid" => "456",
    "email" => "john@example.com",
    "createdat" => 1640000000000
  })
  |> Event.build()

# 2. Encode to Pulsar message (automatically uses attribute map format and embeds schema)
schema_name = "com.example.UserCreated"
{:ok,  pulsar_body} = Cloudevents.to_pulsar_message(event, schema_name)

# 3. Decode back to CloudEvent (uses embedded schema, parses attribute map automatically)
{:ok, decoded_event} = Cloudevents.from_pulsar_message(pulsar_body)

# 4. Access CloudEvent attributes and domain data
IO.inspect(decoded_event.type)  # "com.example.user.created"
IO.inspect(decoded_event.data["userid"])  # "456"
IO.inspect(decoded_event.data["email"])   # "john@example.com"
IO.inspect(decoded_event.data["createdat"])  # 1640000000000
```

## Usage

### Creating CloudEvents

You can create CloudEvents in two ways: using the **builder pattern** or using `from_map/1` with a pre-built map.

#### With Builder

The Event module provides several functions `with_` to add fields to a map in a pipe-friendly way. `Event.new()` creates a map with
`specversion` set to "1.0", an auto-generated uuid4 for `id` and the `time` set. Then you can add more fields, in particular with `Event.with_data` for your domain data. When done use `Event.build()`.

```elixir
alias Cloudevents.Event

# Basic event with required fields
{:ok, event} =
  Event.new()
  |> Event.with_type("com.example.user.created")
  |> Event.with_source("/users/service")
  |> Event.with_data(%{
    "userid" => "456",
    "email" => "john@example.com",
    "createdat" => 1640000000000
  })
  |> Event.build()

# Event with extension attributes
{:ok, event} =
  Event.new()
  |> Event.with_type("com.example.order.placed")
  |> Event.with_source("/orders/service")
  |> Event.with_extension("priority", "high")
  |> Event.with_extension("traceid", "trace-abc123")
  |> Event.with_data(%{"orderid" => "789", "amount" => 99.99})
  |> Event.build()

```

**Builder Functions:**
- `Event.new()` - Start with auto-generated ID and timestamp
- `Event.with_type(builder, type)` - Set event type (required)
- `Event.with_source(builder, source)` - Set event source (required)
- `Event.with_id(builder, id)` - Set event ID
- `Event.with_data(builder, data)` - Set event payload
- `Event.with_subject(builder, subject)` - Set optional subject
- `Event.with_time(builder, time)` - Set timestamp (DateTime or string)
- `Event.with_datacontenttype(builder, type)` - Set content type
- `Event.with_dataschema(builder, schema)` - Set data schema URI
- `Event.with_extension(builder, name, value)` - Add single extension attribute
- `Event.with_extensions(builder, map)` - Add multiple extension attributes at once
- `Event.build(builder)` - Validate and build the final Event struct

**Helper Functions:**
- `Event.generate_id()` - Generate a UUID v4
- `Event.format_time(datetime)` - Format DateTime to ISO8601 string

#### Map-Based Creation

For simple cases or when working with external data, use `from_map/1`:

```elixir
alias Cloudevents.Event

# CloudEvent with domain data in the data field
{:ok, event} = Event.from_map(%{
  "specversion" => "1.0",
  "type" => "com.example.user.created",
  "source" => "/users/service",
  "id" => "user-123",
  "data" => %{
    "userid" => "456",
    "email" => "john@example.com",
    "createdat" => 1640000000000
  }
})

# CloudEvent with extension attributes (for event metadata)
{:ok, event} = Event.from_map(%{
  "specversion" => "1.0",
  "type" => "com.example.order.placed",
  "source" => "/orders/service",
  "id" => "order-789",
  "priority" => "high",        # extension attribute
  "traceid" => "trace-abc123", # extension attribute
  "data" => %{
    "orderid" => "789",
    "amount" => 99.99
  }
})
```

### Encoding and Decoding

Work with Pulsar messages using domain-specific Avro schemas:

```elixir
# Use different schemas for different event types
{:ok, body} = Cloudevents.to_pulsar_message(order_event, "com.example.OrderPlaced")

# Decoding automatically uses the embedded schema, no schema name needed
{:ok, order} = Cloudevents.from_pulsar_message(body)
```

## CloudEvents Avro Format

This library implements the [official CloudEvents Avro Event Format](https://github.com/cloudevents/spec/blob/main/cloudevents/formats/avro-format.md).

### Schema Structure

All CloudEvents Avro schemas must have exactly two fields:

1. **`attribute`** - A map containing:
   - All CloudEvent context attributes (`specversion`, `type`, `source`, `id`, etc.)
   - Optional CloudEvent attributes (`subject`, `time`, `datacontenttype`, `dataschema`)
   - Extension attributes (custom metadata like `priority`, `traceid`)

2. **`data`** - A union type containing your domain-specific payload

### How It Works

When you encode a CloudEvent:
```elixir
# Your CloudEvent struct
%Event{
  specversion: "1.0",
  type: "com.example.user.created",
  source: "/users",
  id: "123",
  data: %{"userid" => "456", "email" => "test@example.com"}
}

# Gets transformed to Avro format:
%{
  "attribute" => %{
    "specversion" => "1.0",
    "type" => "com.example.user.created",
    "source" => "/users",
    "id" => "123"
  },
  "data" => %{"userid" => "456", "email" => "test@example.com"}
}
```

This transformation happens automatically - you don't need to manage it manually!


## Configuration

The `Cloudevents` application starts automatically with Avro support included. Configure it in your `config/config.exs`.

All configuration is set under the `:pulsar_avro_cloudevents` application key and is automatically passed to [Avrora](https://github.com/Strech/avrora) when the application starts.

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `registry_url` | `String.t()` | `nil` | URL of the Confluent Schema Registry (e.g., `"http://localhost:8081"`) |
| `schemas_path` | `String.t()` | `"./priv/schemas"` | Path to local `.avsc` schema files |
| `registry_auth` | `{:basic, [String.t(), ...]}` | `nil` | Basic auth credentials for Schema Registry |
| `registry_schemas_autoreg` | `boolean()` | `true` | Automatically register schemas with the registry |
| `convert_null_values` | `boolean()` | `false` | Convert `nil` values to `:null` atoms for Avro encoding |
| `convert_map_to_proplist` | `boolean()` | `false` | Convert maps to proplists for Avro encoding |
| `names_cache_ttl` | `:infinity \| non_neg_integer()` | `:infinity` | Schema names cache TTL |

For additional Avrora configuration options, see the [Avrora documentation](https://hexdocs.pm/avrora/readme.html#configuration).

### Configuration Examples

**Local Schemas Only**

Use local Avro schema files without a Schema Registry:

```elixir
config :pulsar_avro_cloudevents,
  schemas_path: Path.expand("../priv/schemas", __DIR__)
```

**Local Schema Registry (HTTP)**

Connect to a local Schema Registry for development:

```elixir
config :pulsar_avro_cloudevents,
  registry_url: "http://localhost:8081"
```

**Production Schema Registry (HTTPS with SSL)**

Connect to a production Schema Registry with SSL/TLS and authentication:

```elixir
config :pulsar_avro_cloudevents,
  registry_url: "https://schema-registry.example.com",
  registry_auth: {:basic, ["username", "password"]}
```

**Note:** For SSL configuration options, refer to the [Avrora documentation](https://hexdocs.pm/avrora/readme.html#configuration) and set them under `:pulsar_avro_cloudevents`.


## Acknowledgments

This library is derived from the original [cloudevents-ex](https://github.com/kevinbuch/cloudevents-ex) by Kevin Buchanan. Thank you for the foundational work!
