defmodule AstraAutoExWeb.Plugs.SetupRedirect do
  @moduledoc """
  Redirects all requests to /setup when no users exist in the database.
  Once a user is created through the setup wizard, this plug becomes a no-op.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  def init(opts), do: opts

  def call(%Plug.Conn{request_path: "/setup" <> _} = conn, _opts), do: conn
  def call(%Plug.Conn{request_path: "/users/" <> _} = conn, _opts), do: conn
  def call(%Plug.Conn{request_path: "/dev/" <> _} = conn, _opts), do: conn
  def call(%Plug.Conn{request_path: "/assets/" <> _} = conn, _opts), do: conn

  def call(conn, _opts) do
    if AstraAutoEx.Accounts.user_count() == 0 do
      conn
      |> redirect(to: "/setup")
      |> halt()
    else
      conn
    end
  end
end
