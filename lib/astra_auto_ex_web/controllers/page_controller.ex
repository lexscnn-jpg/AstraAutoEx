defmodule AstraAutoExWeb.PageController do
  use AstraAutoExWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
