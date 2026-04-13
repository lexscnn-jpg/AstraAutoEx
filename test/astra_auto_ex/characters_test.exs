defmodule AstraAutoEx.CharactersTest do
  use AstraAutoEx.DataCase

  alias AstraAutoEx.{Characters, Projects}

  setup do
    {:ok, user} =
      AstraAutoEx.Accounts.register_user(%{
        email: "char_test_#{System.unique_integer([:positive])}@example.com",
        username: "chartest#{System.unique_integer([:positive])}",
        password: "password123456"
      })

    {:ok, project} = Projects.create_project(user.id, %{"name" => "Char Test"})
    %{user: user, project: project}
  end

  describe "characters" do
    test "create and list", %{user: user, project: project} do
      {:ok, char} =
        Characters.create_character(%{
          project_id: project.id,
          user_id: user.id,
          name: "Alice",
          gender: "female",
          description: "A brave young woman"
        })

      assert char.name == "Alice"

      chars = Characters.list_characters(project.id)
      assert length(chars) == 1
      assert hd(chars).name == "Alice"
    end

    test "update character", %{user: user, project: project} do
      {:ok, char} =
        Characters.create_character(%{
          project_id: project.id,
          user_id: user.id,
          name: "Bob"
        })

      {:ok, updated} = Characters.update_character(char, %{name: "Bobby", description: "Updated"})
      assert updated.name == "Bobby"
    end

    test "delete character", %{user: user, project: project} do
      {:ok, char} =
        Characters.create_character(%{
          project_id: project.id,
          user_id: user.id,
          name: "Delete Me"
        })

      assert {:ok, _} = Characters.delete_character(char)
      assert Characters.list_characters(project.id) == []
    end
  end

  describe "appearances" do
    test "create and list appearances", %{user: user, project: project} do
      {:ok, char} =
        Characters.create_character(%{
          project_id: project.id,
          user_id: user.id,
          name: "Test"
        })

      {:ok, app} =
        Characters.create_appearance(%{
          character_id: char.id,
          description: "Casual outfit",
          is_primary: true
        })

      assert app.description == "Casual outfit"

      appearances = Characters.list_appearances(char.id)
      assert length(appearances) == 1
    end

    test "update appearance image", %{user: user, project: project} do
      {:ok, char} =
        Characters.create_character(%{project_id: project.id, user_id: user.id, name: "T"})

      {:ok, app} = Characters.create_appearance(%{character_id: char.id, description: "Test"})

      {:ok, updated} =
        Characters.update_appearance(app, %{image_url: "https://example.com/avatar.png"})

      assert updated.image_url == "https://example.com/avatar.png"
    end
  end
end
