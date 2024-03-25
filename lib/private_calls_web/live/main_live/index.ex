defmodule PrivateCallsWeb.MainLive.Index do
  use PrivateCallsWeb, :live_view_without_layout
  import PrivateCallsWeb.AppComponents

  alias PrivateCalls.Chats

  @impl true
  def mount(_params, _session, socket) do
    chats = Chats.list_chats()
    {:ok, socket |> assign(:chats, chats) |> assign(:selected_chat, nil)}
  end

  @impl true
  def handle_params(unsigned_params, _uri, socket) do
    {selected_chat_id, _} = Integer.parse(unsigned_params["id"] || "0")
    selected_chat = Chats.get_chat(selected_chat_id)
    {:noreply, assign(socket, :selected_chat, selected_chat)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.app_header current_user={@current_user} />

    <div class="flex">
      <aside class="flex flex-col bg-zinc-900 w-48 h-screen">
        <div class="p-2">
          <.input placeholder="Search" name="search" value="" />
        </div>
        <%= for chat <- @chats do %>
          <.link patch={~p"/chats/#{chat.id}"}>
            <.button class={[
              "rounded-none w-48 text-start",
              @selected_chat && chat.id == @selected_chat.id && "!text-red-600"
            ]}>
              <%= chat.name %>
            </.button>
          </.link>
        <% end %>
      </aside>
      <%= if @selected_chat do %>
        <div><%= @selected_chat.name %></div>
      <% end %>
    </div>
    """
  end
end
