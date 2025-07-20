defmodule Hangman2Web.Live.ConnectFour.Game do
  use Hangman2Web, :live_view
  require Logger
  alias Hangman2.Accounts
  alias Hangman2.PubSub
  alias Hangman2Web.Presence
  alias Phoenix.Socket.Broadcast

  @presence_topic "game:lobby" # Define the topic
  @presence_key "in_connectfour" # presence key to tack
  @game_invite_topic "game:invite"
  @game_invite_event "pending_invite"

@impl true
def mount(_params, session, socket) do
  socket =
    assign_new(socket, :current_user, fn ->
      user_token = session["user_token"]
      Accounts.get_user_by_session_token(user_token)
    end)

  if connected?(socket) do
    Logger.debug("ConnectFourGame:connectedSocket: assigns #{inspect(socket.assigns)}")
    Phoenix.PubSub.subscribe(PubSub, @presence_topic)
    Phoenix.PubSub.subscribe(PubSub, @game_invite_topic)
    {:ok, _ref} = Presence.track(
      self(),
      @presence_topic,
      to_string(socket.assigns.current_user.id),
      %{user_id: socket.assigns.current_user.id, user_email: socket.assigns.current_user.email})

    inConnectFourUsers = get_in_connectfour_users(socket.assigns.current_user)

    # Assign the user_token and user_id if current_user is present
    socket =
      socket
      |> assign(:user_token, session["user_token"])
      |> assign(:inConnectFourUserCount, Enum.count(inConnectFourUsers))
      |> assign(:inConnectFourUsers, inConnectFourUsers)
      |> assign(%{pending_invite: nil})
      |> maybe_assign_user_id()

    {:ok, socket}
  else
    {:ok, socket}
  end
end

@impl true
def handle_info(%Broadcast{event: "presence_diff", payload: %{joins: joins, leaves: leaves}} = _event, socket) do
  Logger.debug("Presence_diff event:current_user:#{socket.assigns.current_user.id}, pid: #{inspect(self())} joins:#{inspect(joins)}, leaves: #{inspect(leaves)}")

  inConnectFourUsers = get_in_connectfour_users(socket.assigns.current_user)

  {:noreply, assign(socket, %{inConnectFourUserCount: Enum.count(inConnectFourUsers), inConnectFourUsers: inConnectFourUsers})}
end

def handle_info(%Broadcast{topic: @game_invite_topic = topic, event: @game_invite_event, payload: {:invitee_email, invitee_email}} = _event, socket) do
  Logger.debug("Received #{inspect(@game_invite_event)}: topic: #{inspect(topic)}, payload: #{inspect(invitee_email)}")


  {:noreply, assign(socket, %{pending_invite: %{ user_email: invitee_email}})}
end

  # def handle_info({:presence_diff, diff}, socket) do
  #   IO.inspect(diff, label: "Presence Diff in LiveView")
  #   available_users = list_available_users()
  #   {:noreply, assign(socket, available_users: available_users)}
  # end

  # def handle_info(%{event: "presence_diff", payload: diff}, socket) do
  #   IO.inspect(diff, label: "Presence Diff")

  #   available_users = list_available_users()
  #   {:noreply, assign(socket, available_users: available_users)}
  # end


  # def handle_info({:join_game, game}, socket) do
  #   Logger.info("join_game event fired. game: #{inspect(game)}")

  #   {:noreply, socket}
  # end

  # def handle_info({:make_move, game}, socket) do
  #   Logger.info("make_move event fired. game: #{inspect(game)}")

  #   {:noreply, socket}
  # end

  def handle_event("invite", %{ "user_email" => user_email }, socket) do
    Logger.debug("ConnectFour:LiveView:Event:invited user with email: #{inspect(user_email)}")
    Phoenix.PubSub.broadcast!(PubSub, @game_invite_topic, %Broadcast{
        topic: @game_invite_topic,
        event: @game_invite_event,
        payload: {:invitee_email, user_email}
      })

    {:noreply, assign(socket, %{pending_invite: %{ user_email: user_email}})}
  end

  # def handle_event("start_game", %{ "value" => _value }, socket) do
  #   Logger.debug("ConnectFour:LiveView:mount():socket #{inspect(socket)}")
  #   game = get_game(socket.assigns)
  #   game_id = ConnectFour.game_id(game)
  #   Phoenix.PubSub.subscribe(PubSub, "game:#{game_id}")

  #   {:noreply, assign(socket, %{connect_four_game: game})}
  # end

  # def handle_event("make_move", %{ "col_index" => col_index }, socket) do
  #   if is_integer(col_index) and col_index in [0..6] do
  #     game = ConnectFour.make_move(socket.assigns.connect_four_game, socket.current_user.id, col_index)
  #     { :noreply, assign(socket, :connect_four_game, game) }
  #   else
  #     { :noreply, socket }
  #   end
  # end

  # def handle_event("play_again", _params, socket) do
  #   game = ConnectFour.play_again(socket.assigns.connect_four_game)
  #   { :noreply, assign(socket, :connect_four_game, game) }
  # end

  @impl true
  def render(%{inConnectFourUserCount: user_count, inConnectFourUsers: users} = assigns) do
    Logger.debug("Live.ConnectFour.Game:render: Render for current_user: #{assigns.current_user.id}, inConnectFourUsers #{inspect(users)}")
    ~H"""
    <div class="max-w-xl mx-auto mt-8 space-y-6">
      <h1 class="text-2xl font-bold text-center">Connect Four Lobby</h1>
      <div>
        <label>Available user count:</label>
        <span>{user_count}</span>
      </div>
      <button
        class="w-full bg-blue-600 text-white py-2 px-4 rounded hover:bg-blue-700"
        phx-click="start_game">
        Start New Game
      </button>

      <h2 class="text-xl mt-6 font-semibold">Invite Another Player</h2>

      <div>
        <h2 class="text-xl font-bold">Available Users:</h2>
      </div>

      <%= if !@pending_invite do %>
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <%= for user <- @inConnectFourUsers do %>
          <div class="p-4 border rounded flex items-center justify-between shadow-sm">
            <div><%= user.user_email %></div>
            <button
              class="bg-green-500 text-white px-3 py-1 rounded hover:bg-green-600 text-sm"
              phx-click="invite"
              phx-value-user_email={user.user_email}>
              Invite
            </button>
          </div>
        <% end %>
      </div>
      <% end %>

      <%= if @pending_invite do %>
        <div class="mt-4 text-yellow-800 bg-yellow-100 border border-yellow-400 p-3 rounded">
          Waiting for <strong><%= @pending_invite.user_email %></strong> to accept the game...
        </div>
      <% end %>
    </div>
    """
  end


  @doc """
  No need to return any html for 1st static html render
  """
  def render (assigns) do
    ~H"""
    """
  end

  def get_game(%{connect_four_game: game} = _assigns) do
    game
  end
  def get_game(assigns) do
    ConnectFour.new_game(assigns.current_user.id)
  end

  defp get_in_connectfour_users(current_user) do
      Presence.list(@presence_topic)
      |> Enum.flat_map(fn {_key, %{metas: metas}} -> metas end)
      |> Enum.filter(fn meta -> meta.user_id != current_user.id end)
      |> Enum.uniq_by(& &1.user_id)
          # %{@presence_key => %{metas: list}} ->
      #   # Logger.debug("ConnectFour Game Users List #{inspect(list)}")
      #   list
      #   |> Enum.filter(fn u -> u.user_id != current_user.id end)
      #   |> Enum.uniq()
      # _other -> []
  end


  defp list_available_users() do
    []
    # Presence.list("game:lobby")
    # |> tap(fn users -> IO.inspect(users, label: "Presence.list users") end)
    # |> Enum.map(fn {user_id, %{metas: [meta | _]}} ->
    #   %{user_id: user_id, status: meta.status}
    # end)
  end

  # defp list_available_users() do
  #   Presence.list(@presence_topic)
  #   |> Enum.map(fn {user_id, %{metas: [meta | _]}} ->
  #     %{user_id: user_id, status: meta.status}
  #   end)
  # end

  # defp list_available_users() do
  #   Presence.list(@presence_topic)
  #   |> Enum.map(fn {user_id, %{metas: metas}} ->
  #     %{user_id: user_id, status: metas |> List.first() |> Map.get(:status)}
  #   end)
  # end

  defp maybe_assign_user_id(socket) do
    case socket.assigns[:current_user] do
      %Accounts.User{id: user_id} -> assign(socket, :user_id, user_id)
      _ -> socket
    end
  end

  # defp list_available_users() do
  #   Presence.list(@presence_topic)
  # end

  # defp get_current_user(socket) do
  #   socket.assigns[:current_user] || %{id: 1, name: "Guest"}
  # end

end
