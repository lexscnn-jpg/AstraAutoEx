defmodule AstraAutoExWeb.PageControllerTest do
  use AstraAutoExWeb.ConnCase

  test "GET / redirects to /setup when no users exist", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == "/setup"
  end

  test "GET / shows landing page when users exist", %{conn: conn} do
    # Create a user so SetupRedirect doesn't trigger
    _user = AstraAutoEx.AccountsFixtures.user_fixture()
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "AstrAuto Drama"
  end
end
