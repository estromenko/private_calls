defmodule PrivateCallsWeb.MainLive.Index do
  use PrivateCallsWeb, :live_view_without_layout
  import PrivateCallsWeb.AppComponents

  alias PrivateCalls.Chats

  @impl true
  def mount(_params, _session, socket) do
    chats = Chats.list_chats()
    {:ok, socket |> assign(:chats, chats) |> assign(:selected_chat, 0)}
  end

  @impl true
  def handle_event("select_chat", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected_chat, id)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.app_header current_user={@current_user} />

    <aside class="flex flex-col bg-zinc-900 w-48 h-screen">
      <div class="p-2">
        <.input placeholder="Search" name="search" value="" />
      </div>
      <%= for chat <- @chats do %>
        <.button
          phx-click="select_chat"
          phx-value-id={chat.id}
          class={["rounded-none w-48 text-start", "#{chat.id}" == @selected_chat && "text-red-600"]}
        >
          <%= chat.name %>
        </.button>
      <% end %>
    </aside>
    """
  end
end
