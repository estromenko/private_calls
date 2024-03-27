defmodule PrivateCallsWeb.MainLive.Index do
  alias PrivateCalls.Messages
  use PrivateCallsWeb, :live_view_without_layout
  import PrivateCallsWeb.AppComponents

  alias PrivateCalls.Chats

  @impl true
  def mount(_params, _session, socket) do
    chats = Chats.list_chats()

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
    message = %{
      text: message_text,
      sender_id: socket.assigns.current_user.id,
      chat_id: socket.assigns.selected_chat.id
    }

    Messages.create_message(message)

    PrivateCallsWeb.Endpoint.broadcast(
      "chat_#{socket.assigns.selected_chat.id}",
      "new_message",
      message
    )

    {:noreply, assign(socket, message_form: to_form(%{"message" => ""}))}
  end

  @impl true
  def handle_event("change_message", %{"message" => message_text}, socket) do
    {:noreply, assign(socket, message_form: to_form(%{"message" => message_text}))}
  end

  @impl true
  def handle_event("process_escape", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/chats/")}
  end

  @impl true
  def handle_info(%{event: "new_message", payload: message}, socket) do
    {:noreply, update(socket, :messages, &(&1 ++ [message]))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.app_header current_user={@current_user} />

    <div class="flex h-[calc(100vh-50px)] w-full" phx-window-keydown="process_escape" phx-key="Escape">
      <aside class="flex flex-col bg-zinc-900 w-72">
        <div class="p-2">
          <.form for={@search_form} phx-change="search">
            <.input placeholder="Search" id="search" field={@search_form[:search]} />
          </.form>
        </div>
        <div class="w-full">
          <%= for chat <- @chats do %>
            <.link patch={~p"/chats/#{chat.id}"}>
              <.button class={[
                "rounded-none w-full text-start outline-none",
                @selected_chat && chat.id == @selected_chat.id && "!text-slate-400"
              ]}>
                <%= chat.name %>
              </.button>
            </.link>
          <% end %>
        </div>
      </aside>
      <div class="w-full">
        <%= if @selected_chat do %>
          <div class="h-full flex flex-col justify-between">
            <div class="bg-zinc-600 text-white p-4"><%= @selected_chat.name %></div>
            <div class="flex flex-col gap-4 overflow-y-scroll h-full p-4">
              <%= for message <- @messages do %>
                <div class={[message.sender_id == @current_user.id && "flex justify-end"]}>
                  <div class={[
                    "group p-2 inline-block shadow rounded relative",
                    message.sender_id == @current_user.id && "bg-slate-400 text-white"
                  ]}>
                    <span><%= message.text %></span>
                    <%= if message.sender_id == @current_user.id do %>
                      <div class={[
                        "transition-all opacity-0 group-hover:opacity-100",
                        "absolute top-[-30px] right-0 bg-white shadow p-1 rounded"
                      ]}>
                        <.icon name="hero-trash" class="text-black h-4 w-4" />
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
            <div class="p-4">
              <.form for={@message_form} phx-submit="send_message" phx-change="change_message">
                <.input field={@message_form[:message]} />
              </.form>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
