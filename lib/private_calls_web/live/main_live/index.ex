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
     |> assign(message_form: to_form(%{"message" => ""}))}
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

  @impl true
  def handle_event("message_typing", %{"message" => message_text}, socket) do
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
  def render(assigns) do
    ~H"""
    <.flash_group flash={@flash} />
    <.app_header current_user={@current_user} />
    <div
      class="flex h-[calc(100vh-50px)] w-full"
      phx-window-keydown="process_escape_key"
      phx-key="Escape"
    >
      <aside class="flex flex-col bg-zinc-900 w-72">
        <div class="p-2">
          <.form for={@search_form} phx-change="search">
            <.input placeholder="Search" id="search" field={@search_form[:search]} />
          </.form>
        </div>
        <div class="w-full">
          <%= for chat <- @chats do %>
            <.link patch={~p"/chats/#{chat.id}"}>
              <div class={[
                "rounded-none w-full text-start outline-none text-slate-400",
                "flex gap-2 items-center transition-colors p-2 font-bold",
                @selected_chat && chat.id == @selected_chat.id && "!text-white !bg-slate-800"
              ]}>
                <div class="bg-white rounded-full h-8 w-8 flex items-center justify-center text-xl text-black">
                  <%= chat.name |> String.at(0) |> String.upcase() %>
                </div>
                <%= chat.name %>
              </div>
            </.link>
          <% end %>
        </div>
      </aside>
      <div class="w-full">
        <%= if !@selected_chat do %>
          <div class="h-full flex justify-center items-center">
            <div>Select chat to start messaging</div>
          </div>
        <% else %>
          <div class="h-full flex flex-col justify-between">
            <div class="bg-slate-800 text-white p-4"><%= @selected_chat.name %></div>
            <%= if length(@messages) == 0 do %>
              <div class="text-center">There are no messages yet</div>
            <% else %>
              <div id="messages" class="flex flex-col gap-4 overflow-y-scroll h-full p-4">
                <%= for message <- @messages do %>
                  <div class={[message.sender_id == @current_user.id && "flex justify-end"]}>
                    <div class={[
                      "flex flex-col items-start",
                      message.sender_id == @current_user.id && "items-end"
                    ]}>
                      <span class="text-xs text-slate-600"><%= message.sender.email %></span>
                      <div class={[
                        "group p-2 inline-block shadow rounded relative",
                        message.sender_id == @current_user.id && "bg-slate-800 text-white"
                      ]}>
                        <span><%= message.text %></span>
                        <%= if message.sender_id == @current_user.id do %>
                          <div
                            id={"message-#{message.id}"}
                            type="button"
                            phx-hook="Message"
                            phx-click="delete_message"
                            phx-value-id={message.id}
                            class={[
                              "transition-all opacity-0 group-hover:opacity-100",
                              "absolute top-[-30px] right-0 bg-white shadow p-1 rounded cursor-pointer"
                            ]}
                          >
                            <.icon name="hero-trash" class="text-black h-4 w-4" />
                          </div>
                        <% end %>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
            <div class="p-4">
              <.form for={@message_form} phx-submit="send_message" phx-change="message_typing">
                <.input field={@message_form[:message]} placeholder="Message" />
              </.form>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
