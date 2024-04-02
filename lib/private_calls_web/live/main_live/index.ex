defmodule PrivateCallsWeb.MainLive.Index do
  alias PrivateCalls.Messages
  use PrivateCallsWeb, :live_view_without_layout
  import PrivateCallsWeb.AppComponents

  alias PrivateCalls.Chats

  @impl true
  def mount(_params, _session, socket) do
    chats = Chats.list_chats()

    PrivateCallsWeb.Endpoint.subscribe("notifications")

    {:ok,
     socket
     |> assign(chats: chats)
     |> assign(selected_chat: nil)
     |> assign(messages: [])
     |> assign(search_form: to_form(%{"search" => ""}))
     |> assign(message_form: to_form(%{"message" => ""}))
     |> assign(typing_users: [])}
  end

  @impl true
  def handle_params(unsigned_params, _uri, socket) do
    {selected_chat_id, _} = Integer.parse(unsigned_params["id"] || "0")
    selected_chat = Chats.get_chat(selected_chat_id)
    messages = Messages.get_chat_messages(selected_chat_id)

    if socket.assigns.selected_chat do
      PrivateCallsWeb.Endpoint.unsubscribe("chat_#{socket.assigns.selected_chat.id}")
    end

    PrivateCallsWeb.Endpoint.subscribe("notifications")
    PrivateCallsWeb.Endpoint.subscribe("chat_#{selected_chat_id}")
    {:noreply, socket |> assign(selected_chat: selected_chat) |> assign(messages: messages)}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    chats = Chats.search_chats_by_name(search)
    {:noreply, assign(socket, chats: chats)}
  end

  @impl true
  def handle_event("send_message", %{"message" => message_text}, socket) do
    if message_text != "" do
      {:ok, message} =
        Messages.create_message(%{
          text: message_text,
          sender_id: socket.assigns.current_user.id,
          chat_id: socket.assigns.selected_chat.id
        })

      message = Messages.get_message(message.id)

      PrivateCallsWeb.Endpoint.broadcast(
        "chat_#{socket.assigns.selected_chat.id}",
        "new_message",
        message
      )

      PrivateCallsWeb.Endpoint.broadcast(
        "notifications",
        "new_notification",
        message
      )

      {:noreply, assign(socket, message_form: to_form(%{"message" => ""}))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("message_typing", %{"message" => message_text}, socket) do
    PrivateCallsWeb.Endpoint.broadcast_from(
      self(),
      "chat_#{socket.assigns.selected_chat.id}",
      "typing",
      socket.assigns.current_user
    )

    Process.send_after(__MODULE__, :cancel_typing, 1000)

    {:noreply, assign(socket, message_form: to_form(%{"message" => message_text}))}
  end

  @impl true
  def handle_event("process_escape_key", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/chats/")}
  end

  @impl true
  def handle_event("delete_message", %{"id" => id}, socket) do
    {message_id, _} = Integer.parse(id)

    message = Enum.find(socket.assigns.messages, &(&1.id == message_id))
    Messages.delete_message(message)

    PrivateCallsWeb.Endpoint.broadcast(
      "chat_#{socket.assigns.selected_chat.id}",
      "delete_message",
      message
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info(%{event: "delete_message", payload: message}, socket) do
    messages = Enum.filter(socket.assigns.messages, &(&1.id != message.id))
    {:noreply, assign(socket, :messages, messages)}
  end

  @impl true
  def handle_info(%{event: "typing", payload: user}, socket) do
    typing_users = socket.assigns.typing_users ++ [user]

    Process.send_after(self(), %{event: :cancel_typing, payload: user}, 1000)
    {:noreply, assign(socket, :typing_users, typing_users)}
  end

  @impl true
  def handle_info(%{event: :cancel_typing, payload: not_typing_user}, socket) do
    typing_users = List.delete(socket.assigns.typing_users, not_typing_user)

    {:noreply, assign(socket, typing_users: typing_users)}
  end

  @impl true
  def handle_info(%{event: "new_message", payload: message}, socket) do
    {:noreply, update(socket, :messages, &(&1 ++ [message]))}
  end

  @impl true
  def handle_info(%{event: "new_notification", payload: message}, socket) do
    if message.chat_id == socket.assigns.selected_chat.id do
      {:noreply, socket}
    else
      chat = Chats.get_chat(message.chat_id)
      {:noreply, put_flash(socket, :message, "#{chat.name}: #{message.text}")}
    end
  end
end
