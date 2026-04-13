defmodule AstraAutoExWeb.WorkspaceLiveTest do
  use AstraAutoExWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias AstraAutoEx.Projects

  setup %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    %{conn: conn, user: user}
  end

  describe "home_live" do
    test "renders project listing", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/home")
      assert html =~ "My Projects" or html =~ "我的项目"
    end

    test "shows story composer", %{conn: conn, user: _user} do
      {:ok, _view, html} = live(conn, ~p"/home")
      assert html =~ "Start Creating" or html =~ "开始创作"
    end
  end

  describe "profile_live" do
    test "renders profile page with provider tabs", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/profile")
      assert html =~ "FAL"
      assert html =~ "ARK"
      assert html =~ "Google"
      assert html =~ "MiniMax"
    end

    test "can switch to models tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/profile")
      html = render_click(view, "switch_tab", %{"tab" => "models"})
      assert html =~ "Image Generation"
      assert html =~ "Video Generation"
    end

    test "can switch to billing tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/profile")
      html = render_click(view, "switch_tab", %{"tab" => "billing"})
      assert html =~ "Balance"
    end
  end

  describe "workspace" do
    setup %{conn: conn, user: user} do
      {:ok, project} =
        Projects.create_project(user.id, %{
          "name" => "Test Drama",
          "type" => "short_drama",
          "aspect_ratio" => "9:16"
        })

      %{conn: conn, user: user, project: project}
    end

    test "renders workspace with project name", %{conn: conn, project: project} do
      {:ok, _view, html} = live(conn, ~p"/projects/#{project.id}")
      assert html =~ "Test Drama"
    end

    test "shows stage navigation", %{conn: conn, project: project} do
      {:ok, _view, html} = live(conn, ~p"/projects/#{project.id}")
      assert html =~ "Script" or html =~ "剧本"
      assert html =~ "Storyboard" or html =~ "分镜"
      assert html =~ "Film" or html =~ "成片"
      assert html =~ "AI Edit" or html =~ "AI 剪辑"
    end

    test "can switch stages", %{conn: conn, project: project} do
      {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}")
      html = render_click(view, "switch_stage", %{"stage" => "script"})
      assert html =~ "Script Breakdown" or html =~ "Script" or html =~ "剧本"

      html = render_click(view, "switch_stage", %{"stage" => "storyboard"})
      assert html =~ "Storyboard" or html =~ "分镜"

      html = render_click(view, "switch_stage", %{"stage" => "film"})
      assert html =~ "Film" or html =~ "成片"

      html = render_click(view, "switch_stage", %{"stage" => "compose"})
      assert html =~ "AI Edit" or html =~ "AI 剪辑"
    end

    test "can start pipeline", %{conn: conn, project: project} do
      {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}")
      html = render_submit(view, "start_pipeline", %{"novel_text" => "A hero's journey begins."})
      assert html =~ "Pipeline started" or html =~ "流水线已启动"
    end

    test "can toggle assistant panel", %{conn: conn, project: project} do
      {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}")
      html = render_click(view, "toggle_assistant")
      assert html =~ "AI Assistant" or html =~ "AI 助手"
    end
  end

  describe "asset_hub" do
    test "renders asset hub", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/asset-hub")
      assert html =~ "Asset Hub" or html =~ "素材库"
    end

    test "can switch tabs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/asset-hub")
      html = render_click(view, "switch_tab", %{"tab" => "locations"})
      assert html =~ "Locations" or html =~ "场景"
    end
  end
end
