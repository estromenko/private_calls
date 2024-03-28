defmodule PrivateCallsWeb.Admin.ChatLiveTest do
  use PrivateCallsWeb.ConnCase

  import Phoenix.LiveViewTest
  import PrivateCalls.ChatsFixtures
  import PrivateCalls.UsersFixtures

  @create_attrs %{name: "some name"}
  @update_attrs %{name: "some updated name"}
  @invalid_attrs %{name: nil}

  defp setup_data(%{conn: conn}) do
    chat = chat_fixture()
    password = valid_user_password()
    user = user_fixture(%{password: password})
    %{chat: chat, conn: log_in_user(conn, user)}
  end

  describe "Index" do
    setup [:setup_data]

    test "lists all chats", %{conn: conn, chat: chat} do
      {:ok, _index_live, html} = live(conn, ~p"/admin/chats")

      assert html =~ "Listing Chats"
      assert html =~ chat.name
    end

    test "saves new chat", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/chats")

      assert index_live |> element("a", "New Chat") |> render_click() =~
               "New Chat"

      assert_patch(index_live, ~p"/admin/chats/new")

      assert index_live
             |> form("#chat-form", chat: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#chat-form", chat: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/admin/chats")

      html = render(index_live)
      assert html =~ "Chat created successfully"
      assert html =~ "some name"
    end

    test "updates chat in listing", %{conn: conn, chat: chat} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/chats")

      assert index_live |> element("#chats-#{chat.id} a", "Edit") |> render_click() =~
               "Edit Chat"

      assert_patch(index_live, ~p"/admin/chats/#{chat}/edit")

      assert index_live
             |> form("#chat-form", chat: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#chat-form", chat: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/admin/chats")

      html = render(index_live)
      assert html =~ "Chat updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes chat in listing", %{conn: conn, chat: chat} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/chats")

      assert index_live |> element("#chats-#{chat.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#chats-#{chat.id}")
    end
  end

  describe "Show" do
    setup [:setup_data]

    test "displays chat", %{conn: conn, chat: chat} do
      {:ok, _show_live, html} = live(conn, ~p"/admin/chats/#{chat}")

      assert html =~ "Show Chat"
      assert html =~ chat.name
    end

    test "updates chat within modal", %{conn: conn, chat: chat} do
      {:ok, show_live, _html} = live(conn, ~p"/admin/chats/#{chat}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Chat"

      assert_patch(show_live, ~p"/admin/chats/#{chat}/show/edit")

      assert show_live
             |> form("#chat-form", chat: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#chat-form", chat: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/admin/chats/#{chat}")

      html = render(show_live)
      assert html =~ "Chat updated successfully"
      assert html =~ "some updated name"
    end
  end
end
