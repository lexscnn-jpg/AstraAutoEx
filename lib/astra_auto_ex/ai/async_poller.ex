defmodule AstraAutoEx.AI.AsyncPoller do
  @moduledoc """
  Unified async task polling. Parses external_id format: PROVIDER:TYPE:...
  Routes to provider-specific poll functions.
  """

  alias AstraAutoEx.AI.Gateway

  @doc """
  Poll an async task by its external_id.
  Returns {:ok, %{status: :pending | :completed | :failed, ...}} | {:error, term()}
  """
  def poll(external_id, user_config \\ %{}) do
    case parse_external_id(external_id) do
      {:ok, {provider, _type, _rest} = parsed} ->
        # The external_id prefix may be a legacy alias (e.g. "OPENAI" for apiyi);
        # map to the actual provider_config key first, THEN fetch config.
        config_key = provider_key_from_prefix(provider)
        config = Map.get(user_config, config_key, Map.get(user_config, provider, %{}))
        do_poll(parsed, config)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_external_id(external_id) do
    case String.split(external_id, ":", parts: 3) do
      [provider, type, rest] ->
        {:ok, {String.downcase(provider), String.downcase(type), rest}}

      _ ->
        {:error, {:invalid_external_id, external_id}}
    end
  end

  defp do_poll({provider, _type, rest}, config) do
    provider_key = provider_key_from_prefix(provider)

    # Some providers (apiyi) prepend a base64-encoded "provider_token" to the
    # video_id, separated by ":". Strip it so the real video_id is passed to
    # poll_task.
    real_id =
      case String.split(rest, ":", parts: 2) do
        [token, id] ->
          case Base.url_decode64(token, padding: false) do
            {:ok, _} -> id
            :error -> rest
          end

        _ ->
          rest
      end

    Gateway.poll_task(provider_key, real_id, config)
  end

  defp provider_key_from_prefix("fal"), do: "fal"
  defp provider_key_from_prefix("ark"), do: "ark"
  defp provider_key_from_prefix("google"), do: "google"
  defp provider_key_from_prefix("minimax"), do: "minimax"
  defp provider_key_from_prefix("openai"), do: "apiyi"
  defp provider_key_from_prefix("runninghub"), do: "runninghub"
  defp provider_key_from_prefix("vidu"), do: "vidu"
  defp provider_key_from_prefix("bailian"), do: "bailian"
  defp provider_key_from_prefix(other), do: other
end
