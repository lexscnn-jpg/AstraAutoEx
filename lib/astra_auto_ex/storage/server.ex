defmodule AstraAutoEx.Storage.Server do
  @moduledoc """
  GenServer that manages the active storage provider singleton.
  Delegates all storage operations to the configured provider.
  """
  use GenServer

  alias AstraAutoEx.Storage.{LocalProvider, S3Provider, Provider}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Client API

  def upload(key, body, opts \\ []), do: call_provider(:upload, [key, body, opts])
  def delete(key), do: call_provider(:delete, [key])
  def delete_many(keys), do: call_provider(:delete_many, [keys])
  def get(key), do: call_provider(:get, [key])

  def get_signed_url(key, expires_in \\ 3600),
    do: call_provider(:get_signed_url, [key, expires_in])

  def exists?(key), do: call_provider(:exists?, [key])

  def generate_key(prefix, ext, opts \\ []) do
    Provider.generate_key(prefix, ext, opts)
  end

  @doc """
  Download from URL and upload to storage. Returns {:ok, storage_key}.
  """
  def download_and_upload(url, key, opts \\ []) do
    headers = Keyword.get(opts, :headers, [])

    case Req.get(url, headers: headers, max_retries: 2, receive_timeout: 120_000) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        ext = Path.extname(key) |> String.trim_leading(".")
        content_type = Provider.mime_from_ext(ext)
        upload(key, body, content_type: content_type)

      {:ok, %{status: status}} ->
        {:error, {:download_failed, status}}

      {:error, reason} ->
        {:error, {:download_failed, reason}}
    end
  end

  # Server

  @impl true
  def init(_opts) do
    provider = resolve_provider()
    {:ok, %{provider: provider}}
  end

  defp call_provider(fun, args) do
    provider = GenServer.call(__MODULE__, :get_provider)
    apply(provider, fun, args)
  end

  @impl true
  def handle_call(:get_provider, _from, state) do
    {:reply, state.provider, state}
  end

  defp resolve_provider do
    case Application.get_env(:astra_auto_ex, :storage_type, "local") do
      "local" -> LocalProvider
      "s3" -> S3Provider
      other -> raise "Unsupported storage type: #{other}"
    end
  end
end
