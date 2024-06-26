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
     |> assign(typing_users: [])
     |> assign(users_in_call: [])}
  end

  @impl true
  def handle_params(unsigned_params, _uri, socket) do
    {selected_chat_id, _} = Integer.parse(unsigned_params["id"] || "0")
    selected_chat = Chats.get_chat(selected_chat_id)
    messages = Messages.get_chat_messages(selected_chat_id)

    if socket.assigns.selected_chat do
      PrivateCallsWeb.Endpoint.unsubscribe("chat_#{socket.assigns.selected_chat.id}")

      if socket.assigns.live_action == :video do
        PrivateCallsWeb.Endpoint.subscribe("user_#{socket.assigns.current_user.id}")

        PrivateCallsWeb.Endpoint.broadcast_from(
          self(),
          "notifications",
          "call",
          selected_chat.name
        )

        PrivateCallsWeb.UserPresence.track(
          self(),
          "chat_#{selected_chat_id}",
          socket.assigns.current_user.id,
          socket.assigns.current_user
        )
      else
        PrivateCallsWeb.Endpoint.unsubscribe("user_#{socket.assigns.current_user.id}")

        PrivateCallsWeb.UserPresence.untrack(
          self(),
          "chat_#{selected_chat_id}",
          socket.assigns.current_user.id
        )
      end
    end

    PrivateCallsWeb.Endpoint.subscribe("notifications")
    PrivateCallsWeb.Endpoint.subscribe("chat_#{selected_chat_id}")

    {:noreply,
     socket
     |> assign(selected_chat: selected_chat)
     |> assign(messages: messages)
     |> assign(users_in_call: get_users_in_call(selected_chat_id))}
  end

  def get_users_in_call(selected_chat_id) do
    PrivateCallsWeb.UserPresence.list("chat_#{selected_chat_id}")
    |> Enum.map(fn {_user_id, user} ->
      List.first(user[:metas])
    end)
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    chats = Chats.search_chats_by_name(search)
    {:noreply, assign(socket, chats: chats)}
  end

  @impl true
  def handle_event("send_message", %{"message" => message_text}, socket) do
    if message_text == "" do
      {:noreply, socket}
    else
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
  def handle_event("rtc_message", %{"message" => message}, socket) do
    PrivateCallsWeb.Endpoint.broadcast_from(
      self(),
      "user_#{message["toUserId"]}",
      "rtc_message",
      message
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("rtc_close", %{"userId" => user_id}, socket) do
    PrivateCallsWeb.Endpoint.broadcast_from(
      self(),
      "chat_#{socket.assigns.selected_chat.id}",
      "rtc_close",
      user_id
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info(%{event: "rtc_message", payload: message}, socket) do
    {:noreply, push_event(socket, "rtc_message", message)}
  end

  @impl true
  def handle_info(%{event: "rtc_close", payload: user_id}, socket) do
    {:noreply, push_event(socket, "rtc_close", %{user_id: user_id})}
  end

  @impl true
  def handle_info(%{event: "delete_message", payload: message}, socket) do
    messages = Enum.filter(socket.assigns.messages, &(&1.id != message.id))
    {:noreply, assign(socket, :messages, messages)}
  end

  @impl true
  def handle_info(%{event: "typing", payload: user}, socket) do
    Process.send_after(self(), %{event: :cancel_typing, payload: user}, 1000)
    {:noreply, assign(socket, :typing_users, [socket.assigns.typing_users | user])}
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

  @impl true
  def handle_info(%{event: "call", payload: chat_name}, socket) do
    {:noreply,
     put_flash(
       socket,
       :message,
       "#{socket.assigns.current_user.email} just joined chat \"#{chat_name}\""
     )}
  end

  @impl true
  def handle_info(%{event: "presence_diff", payload: _payload}, socket) do
    users_in_call = get_users_in_call(socket.assigns.selected_chat.id)
    {:noreply, assign(socket, users_in_call: users_in_call)}
  end
end
