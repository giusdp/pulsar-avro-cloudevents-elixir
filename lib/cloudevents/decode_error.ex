defmodule Cloudevents.DecodeError do
  @moduledoc "Error while decoding a Cloudevent."
  defexception [:cause]

  @impl true
  def message(%{cause: cause}) when is_binary(cause) do
    "Failed to decode Cloudevent: #{cause}"
  end

  def message(%{cause: cause}) do
    "Failed to decode Cloudevent: #{Exception.message(cause)}"
  end
end
