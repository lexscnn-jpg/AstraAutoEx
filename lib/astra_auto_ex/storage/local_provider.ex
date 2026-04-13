defmodule AstraAutoEx.Storage.LocalProvider do
  @moduledoc """
  Local filesystem storage provider.
  Files are stored under a configurable upload directory.
  """
  @behaviour AstraAutoEx.Storage.Provider

  @default_upload_dir "priv/uploads"

  defp upload_dir do
    Application.get_env(:astra_auto_ex, :upload_dir, @default_upload_dir)
  end

  @impl true
  def upload(key, body, _opts \\ []) do
    path = full_path(key)
    dir = Path.dirname(path)
    File.mkdir_p!(dir)

    case File.write(path, body) do
      :ok -> {:ok, key}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete(key) do
    path = full_path(key)

    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete_many(keys) do
    deleted =
      Enum.reduce(keys, 0, fn key, acc ->
        case delete(key) do
          :ok -> acc + 1
          _ -> acc
        end
      end)

    {:ok, deleted}
  end

  @impl true
  def get(key) do
    path = full_path(key)

    case File.read(path) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def get_signed_url(key, _expires_in) do
    {:ok, "/api/files/#{key}"}
  end

  @impl true
  def exists?(key) do
    full_path(key) |> File.exists?()
  end

  defp full_path(key) do
    safe_key = key |> String.replace("..", "") |> String.trim_leading("/")
    Path.join(upload_dir(), safe_key)
  end
end
