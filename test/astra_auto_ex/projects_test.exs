defmodule AstraAutoEx.ProjectsTest do
  use AstraAutoEx.DataCase

  alias AstraAutoEx.Projects

  setup do
    {:ok, user} =
      AstraAutoEx.Accounts.register_user(%{
        email: "proj_test_#{System.unique_integer([:positive])}@example.com",
        username: "projtest#{System.unique_integer([:positive])}",
        password: "password123456"
      })

    %{user: user}
  end

  describe "create_project/2" do
    test "creates a project with valid attrs", %{user: user} do
      attrs = %{"name" => "Test Project", "type" => "short_drama", "aspect_ratio" => "9:16"}
      assert {:ok, project} = Projects.create_project(user.id, attrs)
      assert project.name == "Test Project"
      assert project.type == "short_drama"
      assert project.aspect_ratio == "9:16"
      assert project.user_id == user.id
    end

    test "fails without name", %{user: user} do
      assert {:error, changeset} = Projects.create_project(user.id, %{"type" => "standard"})
      assert %{name: _} = errors_on(changeset)
    end
  end

  describe "list_projects/1" do
    test "returns user's projects", %{user: user} do
      {:ok, _} = Projects.create_project(user.id, %{"name" => "P1"})
      {:ok, _} = Projects.create_project(user.id, %{"name" => "P2"})
      projects = Projects.list_projects(user.id)
      assert length(projects) == 2
    end

    test "doesn't return other user's projects", %{user: user} do
      {:ok, other} =
        AstraAutoEx.Accounts.register_user(%{
          email: "other_#{System.unique_integer([:positive])}@example.com",
          username: "other#{System.unique_integer([:positive])}",
          password: "password123456"
        })

      {:ok, _} = Projects.create_project(other.id, %{"name" => "Other's project"})

      projects = Projects.list_projects(user.id)
      assert projects == []
    end
  end

  describe "delete_project/1" do
    test "deletes a project", %{user: user} do
      {:ok, project} = Projects.create_project(user.id, %{"name" => "To Delete"})
      assert {:ok, _} = Projects.delete_project(project)
      assert Projects.list_projects(user.id) == []
    end
  end
end
