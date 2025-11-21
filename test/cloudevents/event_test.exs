defmodule Cloudevents.EventBuilderTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Cloudevents.Event
  alias Cloudevents.ParseError

  describe "new/0" do
    test "builds complete event with auto-generated ID and timestamp" do
      {:ok, event} =
        Event.new()
        |> Event.with_type("com.example.user.created")
        |> Event.with_source("/users")
        |> Event.with_data(%{"userId" => "456", "email" => "test@example.com"})
        |> Event.build()

      assert is_binary(event.id)
      assert String.length(event.id) == 36
      assert is_binary(event.time)
      assert event.type == "com.example.user.created"
      assert event.source == "/users"
      assert event.data == %{"userId" => "456", "email" => "test@example.com"}
    end

    test "can override auto-generated ID" do
      {:ok, event} =
        Event.new()
        |> Event.with_type("com.example.test")
        |> Event.with_source("/test")
        |> Event.with_id("custom-id-123")
        |> Event.build()

      assert event.id == "custom-id-123"
    end

    test "can override auto-generated timestamp" do
      {:ok, event} =
        Event.new()
        |> Event.with_type("com.example.test")
        |> Event.with_source("/test")
        |> Event.with_time("2020-01-01T00:00:00Z")
        |> Event.build()

      assert event.time == "2020-01-01T00:00:00Z"
    end
  end

  describe "basic builder flow" do
    test "builds a valid event with required fields" do
      {:ok, event} =
        Event.new()
        |> Event.with_type("com.example.user.created")
        |> Event.with_source("/users")
        |> Event.with_id("user-123")
        |> Event.build()

      assert event.specversion == "1.0"
      assert event.type == "com.example.user.created"
      assert event.source == "/users"
      assert event.id == "user-123"
    end

    test "builds event with all optional fields" do
      {:ok, event} =
        Event.new()
        |> Event.with_type("com.example.user.created")
        |> Event.with_source("/users")
        |> Event.with_id("user-123")
        |> Event.with_subject("user/456")
        |> Event.with_time("2023-01-01T12:00:00Z")
        |> Event.with_datacontenttype("application/json")
        |> Event.with_dataschema("https://example.com/schema")
        |> Event.with_data(%{"userId" => "456", "email" => "test@example.com"})
        |> Event.build()

      assert event.subject == "user/456"
      assert event.time == "2023-01-01T12:00:00Z"
      assert event.datacontenttype == "application/json"
      assert event.dataschema == "https://example.com/schema"
      assert event.data == %{"userId" => "456", "email" => "test@example.com"}
    end

    test "builds event with data payload" do
      {:ok, event} =
        Event.new()
        |> Event.with_type("com.example.order.placed")
        |> Event.with_source("/orders")
        |> Event.with_id("order-789")
        |> Event.with_data(%{"orderId" => "789", "amount" => 100.50})
        |> Event.build()

      assert event.data == %{"orderId" => "789", "amount" => 100.50}
    end
  end

  describe "with_time/2" do
    test "accepts DateTime struct and formats to ISO8601" do
      datetime = DateTime.from_naive!(~N[2023-01-01 12:00:00], "Etc/UTC")

      {:ok, event} =
        Event.new()
        |> Event.with_type("com.example.test")
        |> Event.with_source("/test")
        |> Event.with_id("123")
        |> Event.with_time(datetime)
        |> Event.build()

      assert event.time == "2023-01-01T12:00:00Z"
    end

    test "accepts string time directly" do
      {:ok, event} =
        Event.new()
        |> Event.with_type("com.example.test")
        |> Event.with_source("/test")
        |> Event.with_id("123")
        |> Event.with_time("2023-06-15T10:30:00Z")
        |> Event.build()

      assert event.time == "2023-06-15T10:30:00Z"
    end
  end

  describe "extension attributes" do
    test "adds single extension attribute with with_extension/3" do
      {:ok, event} =
        Event.new()
        |> Event.with_type("com.example.test")
        |> Event.with_source("/test")
        |> Event.with_id("123")
        |> Event.with_extension("traceid", "abc-123")
        |> Event.build()

      assert event.extensions["traceid"] == "abc-123"
    end

    test "adds multiple extension attributes with with_extension/3" do
      {:ok, event} =
        Event.new()
        |> Event.with_type("com.example.test")
        |> Event.with_source("/test")
        |> Event.with_id("123")
        |> Event.with_extension("traceid", "abc-123")
        |> Event.with_extension("priority", "high")
        |> Event.build()

      assert event.extensions["traceid"] == "abc-123"
      assert event.extensions["priority"] == "high"
    end

    test "adds multiple extensions with with_extensions/2" do
      {:ok, event} =
        Event.new()
        |> Event.with_type("com.example.test")
        |> Event.with_source("/test")
        |> Event.with_id("123")
        |> Event.with_extensions(%{
          "traceid" => "abc-123",
          "priority" => "high"
        })
        |> Event.build()

      assert event.extensions["traceid"] == "abc-123"
      assert event.extensions["priority"] == "high"
    end

    test "validates extension attribute names" do
      assert {:error, %ParseError{}} =
               Event.new()
               |> Event.with_type("com.example.test")
               |> Event.with_source("/test")
               |> Event.with_id("123")
               # hyphens not allowed
               |> Event.with_extension("invalid-name", "value")
               |> Event.build()
    end
  end

  describe "validation errors from build/1" do
    test "returns error when type is missing" do
      assert {:error, %ParseError{message: "missing type"}} =
               Event.new()
               |> Event.with_source("/test")
               |> Event.with_id("123")
               |> Event.build()
    end

    test "returns error when source is missing" do
      assert {:error, %ParseError{message: "missing source"}} =
               Event.new()
               |> Event.with_type("com.example.test")
               |> Event.with_id("123")
               |> Event.build()
    end

    test "returns error when id is missing" do
      assert {:error, %ParseError{message: "missing id"}} =
               Event.new()
               |> Map.delete("id")
               |> Event.with_type("com.example.test")
               |> Event.with_source("/test")
               |> Event.build()
    end

    test "returns error when optional field is empty string" do
      assert {:error, %ParseError{message: "subject given but empty"}} =
               Event.new()
               |> Event.with_type("com.example.test")
               |> Event.with_source("/test")
               |> Event.with_id("123")
               |> Event.with_subject("")
               |> Event.build()
    end
  end
end
