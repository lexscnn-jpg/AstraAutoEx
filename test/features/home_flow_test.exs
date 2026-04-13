defmodule AstraAutoExWeb.Features.HomeFlowTest do
  use AstraAutoExWeb.FeatureCase

  import Wallaby.Query

  @moduletag :feature

  describe "home page" do
    test "authenticated user sees project listing", %{session: session} do
      %{email: email, password: password} = AstraAutoExWeb.FeatureCase.register_user()

      session
      |> visit("/users/log-in")
      |> fill_in(css("input[name='user[email]']"), with: email)
      |> fill_in(css("input[name='user[password]']"), with: password)
      |> click(css("button[type='submit']"))
      |> visit("/home")
      |> assert_has(css("body"))
    end

    test "unauthenticated user redirected to login", %{session: session} do
      session
      |> visit("/home")
      |> assert_has(css("input[name='user[email]']"))
    end
  end
end
