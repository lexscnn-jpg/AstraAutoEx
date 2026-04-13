defmodule AstraAutoEx.Storage.S3Provider do
  @moduledoc """
  S3/MinIO storage provider using ExAws.
  """
  @behaviour AstraAutoEx.Storage.Provider

  defp config do
    Application.get_env(:astra_auto_ex, :s3, [])
  end

  defp bucket, do: Keyword.fetch!(config(), :bucket)

  defp ex_aws_config do
    conf = config()

    base = [
      access_key_id: Keyword.get(conf, :access_key_id),
      secret_access_key: Keyword.get(conf, :secret_access_key),
      region: Keyword.get(conf, :region, "us-east-1")
    ]

    case Keyword.get(conf, :endpoint) do
      nil ->
        base

      endpoint ->
        uri = URI.parse(endpoint)

        base ++
          [
            host: uri.host,
            port: uri.port,
            scheme: "#{uri.scheme}://",
            s3: [path_style: true]
          ]
    end
  end

  @impl true
  def upload(key, body, opts \\ []) do
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")

    case ExAws.S3.put_object(bucket(), key, body, content_type: content_type)
         |> ExAws.request(ex_aws_config()) do
      {:ok, _} -> {:ok, key}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete(key) do
    case ExAws.S3.delete_object(bucket(), key)
         |> ExAws.request(ex_aws_config()) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete_many(keys) do
    case ExAws.S3.delete_multiple_objects(bucket(), keys)
         |> ExAws.request(ex_aws_config()) do
      {:ok, _} -> {:ok, length(keys)}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def get(key) do
    case ExAws.S3.get_object(bucket(), key)
         |> ExAws.request(ex_aws_config()) do
      {:ok, %{body: body}} -> {:ok, body}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def get_signed_url(key, expires_in) do
    ExAws.S3.presigned_url(ExAws.Config.new(:s3, ex_aws_config()), :get, bucket(), key,
      expires_in: expires_in
    )
  end

  @impl true
  def exists?(key) do
    case ExAws.S3.head_object(bucket(), key)
         |> ExAws.request(ex_aws_config()) do
      {:ok, _} -> true
      _ -> false
    end
  end
end
