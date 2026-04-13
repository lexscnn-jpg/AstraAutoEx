defmodule AstraAutoExWeb.Features.ProfileFlowTest do
  use AstraAutoExWeb.FeatureCase

  import Wallaby.Query

  @moduletag :feature

  setup %{session: session} do
    %{email: email, password: password} = AstraAutoExWeb.FeatureCase.register_user()

    session =
      session
      |> visit("/users/log-in")
      |> fill_in(css("input[name='user[email]']"), with: email)
      |> fill_in(css("input[name='user[password]']"), with: password)
      |> click(css("button[type='submit']"))

    Process.sleep(500)
    %{session: session}
  end

  describe "profile page" do
    test "renders provider configuration", %{session: session} do
      session
      |> visit("/profile")
      |> assert_has(css("body"))
      |> assert_has(Wallaby.Query.text("FAL"))
      |> assert_has(Wallaby.Query.text("ARK"))
      |> assert_has(Wallaby.Query.text("Google"))
      |> assert_has(Wallaby.Query.text("MiniMax"))
    end
  end
end
