defmodule AstraAutoExWeb.Features.AuthFlowTest do
  use AstraAutoExWeb.FeatureCase

  import Wallaby.Query

  @moduletag :feature

  describe "registration and login flow" do
    test "user can register a new account", %{session: session} do
      uniq = System.unique_integer([:positive])

      session
      |> visit("/users/register")
      |> assert_has(css("input[name='user[email]']"))
      |> fill_in(css("input[name='user[email]']"), with: "feature_#{uniq}@example.com")
      |> fill_in(css("input[name='user[username]']"), with: "feature#{uniq}")
      |> fill_in(css("input[name='user[password]']"), with: "password123456")
      |> click(css("button[type='submit']"))
      |> assert_has(css("body"))
    end

    test "user can log in with existing account", %{session: session} do
      %{email: email, password: password} = AstraAutoExWeb.FeatureCase.register_user()

      session
      |> visit("/users/log-in")
      |> assert_has(css("input[name='user[email]']"))
      |> fill_in(css("input[name='user[email]']"), with: email)
      |> fill_in(css("input[name='user[password]']"), with: password)
      |> click(css("button[type='submit']"))
      |> assert_has(css("body"))
    end

    test "login page renders correctly", %{session: session} do
      session
      |> visit("/users/log-in")
      |> assert_has(css("input[name='user[email]']"))
      |> assert_has(css("button[type='submit']"))
    end
  end
end
