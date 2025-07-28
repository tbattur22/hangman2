defmodule Hangman2Web.Live.ConnectFour.Game do
  use Hangman2Web, :live_view
  require Logger
  alias Hangman2.Accounts
  alias Hangman2.PubSub
  alias Hangman2Web.Presence
  alias Hangman2Web.Live.ConnectFour.PresenceUtils
  alias Phoenix.Socket.Broadcast
  alias Hangman2Web.Live.ConnectFour.Invites

  @presence_topic "game:lobby" # Define the topic
  @game_invite_topic "game:invite"
  @update_ui_state_event "update_ui_state"
  @game_join_event "pending_join"

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

    socket =
    if (socket.assigns.current_user) do
      user_id = socket.assigns.current_user.id |> to_string()

      {:ok, _ref} = Presence.track(
        self(),
        @presence_topic,
        user_id,
        %{user_id: socket.assigns.current_user.id, user_name: socket.assigns.current_user.name}
      )

      update_ui_state(socket)
    else
      socket
    end

    # Assign the user_token and user_id if current_user is present
    socket =
      socket
      |> assign(:user_token, session["user_token"])
      |> maybe_assign_user_id()

    {:ok, socket}
  else
    {:ok, socket}
  end
end

  def update_ui_state(socket) do
    # Get deduplicated users as a map
    presence =
      PresenceUtils.unique_users(@presence_topic)
      |> Map.new()  # ✅ convert list of tuples to a map

    # Get list of user_ids that can be invited
    available_user_ids = Invites.get_available_users_to_invite(presence)

    # presence = Presence.list(@presence_topic)
    # presence = PresenceUtils.unique_users(@presence_topic)
    Logger.info("update_ui_states: current_user id: #{socket.assigns.current_user.id}, presence: #{inspect(presence)}")
    # available_users_ids =
    #   Hangman2Web.Live.ConnectFour.Invites.get_available_users_to_invite(presence)

      available_users =
        available_user_ids
        |> Enum.filter(fn uid -> uid != to_string(socket.assigns.current_user.id) end)
        |> Enum.map(fn user_id -> normalizeUser(Accounts.get_user!(user_id)) end)

    # Logger.info("handle_info: current_user id: #{socket.assigns.current_user.id}, new available_users: #{inspect(available_users)}")
    updated_socket =
      socket
      |> assign(%{
          available_users: available_users,
          invites: Invites.get_state(),
          waitingForInvitee: getWaitingForInvitee(socket),
          inviterWaitingForMe: getInviterWaitingForMe(socket)
        })

      send(self(), :should_switch_route)
      Logger.info("update_ui_states: current_user id: #{socket.assigns.current_user.id}, updated_socket: #{inspect(updated_socket)}")

    updated_socket
  end

  def handle_info(:update_ui_states, socket) do
    updated_socket = update_ui_state(socket)

    {:noreply, updated_socket}
  end


  @impl true
  def handle_info(%Broadcast{event: "presence_diff", payload: %{joins: joins, leaves: leaves}} = _event, socket) do
    # Logger.debug("Presence_diff event:current_user:#{socket.assigns.current_user.id}, pid: #{inspect(self())} joins:#{inspect(joins)}, leaves: #{inspect(leaves)} and \n --waitingForInvitee: #{inspect(socket.assigns.waitingForInvitee)} and
    # \n --inviterWaitingForMe: #{inspect(socket.assigns.inviterWaitingForMe)} ")


    {:noreply, update_ui_state(socket)}
  end

  def handle_info(%Broadcast{topic: @game_invite_topic = topic, event: @update_ui_state_event, payload: payload} = _event, socket) do
    Logger.debug("Received #{inspect(@update_ui_state_event)}: topic: #{inspect(topic)}, payload: #{inspect(payload)}")

    send(self(), :update_ui_states)

    {:noreply, socket}
  end

  def handle_info(:should_switch_route, socket) do
    invites_state = Invites.get_state()
    Logger.info("ShouldSwicthRoute: current user id: #{socket.assigns.current_user.id}, invites state #{inspect(invites_state)}")

    case shouldSwitchToPlayRoute(invites_state, socket) do
      {{_u1,_u2}, game_id} ->
        {:noreply, push_navigate(socket, to: ~p"/connect_four/game/#{game_id}")}
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("invite", %{ "user" => userEncoded }, socket) do
    user = Jason.decode!(userEncoded)
    Logger.debug("ConnectFour:LiveView:Event:invited user: #{inspect(user)}")

    Invites.invite(Integer.to_string(socket.assigns.current_user.id), user["id"])

    broadcastUpdateUIStates()
    send(self(), :update_ui_states)

    {:noreply, socket}
  end

  @impl true
  def handle_event("accept_invite", %{ "inviter" => userEncoded }, socket) do
    inviter = Jason.decode!(userEncoded)
    # Logger.debug("ConnectFour:LiveView:Event:accept_invite: inviter: #{inspect(inviter)}")
    # Logger.info("accept_invite handler: current user id: #{socket.assigns.current_user.id}, invites_state: #{inspect(Invites.get_state())}")

    game = get_game(socket.assigns, inviter)
    game_id = ConnectFour.game_id(game)

    Invites.accept(Integer.to_string(inviter["id"]), Integer.to_string(socket.assigns.current_user.id), game_id)

    broadcastUpdateUIStates()
    update_ui_state(socket)

    {:noreply, push_navigate(socket, to: ~p"/connect_four/game/#{game_id}")}
  end

  @impl true
  def handle_event("cancel_invite", _payload, socket) do
    Invites.remove_user(Integer.to_string(socket.assigns.current_user.id))

    broadcastUpdateUIStates()

    {:noreply, update_ui_state(socket)}
  end

  @impl true
  def handle_event("reject_invite", _payload, socket) do
    Invites.remove_user(Integer.to_string(socket.assigns.current_user.id))

    broadcastUpdateUIStates()

    {:noreply, update_ui_state(socket)}
  end


  @impl true
  def render(%{available_users: _available_users} = assigns) do
    Logger.debug("Live.ConnectFour.Game:render: Render for current_user: #{assigns.current_user.id},
    \n assigns #{inspect(assigns)} and
    \n --available_users #{inspect(assigns.available_users)}
    \n --Invites #{inspect(Invites.get_state())}")
    ~H"""
    <div class="max-w-xl mx-auto mt-8 space-y-6">
      <h1 class="text-2xl font-bold text-center">Connect Four Lobby</h1>
      <div>
        <h2 class="text-xl font-bold">Available Users:</h2>
      </div>

      <%= if !@waitingForInvitee and !@inviterWaitingForMe and !Enum.empty?(@available_users) do %>
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <%= for user <- @available_users do %>
          <div class="p-4 border rounded flex items-center justify-between shadow-sm">
            <div><%= user.name %></div>
            <button
              class="bg-green-500 text-white px-3 py-1 rounded hover:bg-green-600 text-sm"
              phx-click="invite"
              phx-value-user={Jason.encode!(user)}>
              Invite
            </button>
          </div>
        <% end %>
      </div>
      <% end %>

      <%= if @waitingForInvitee do %>
        <div class="mt-4 text-yellow-800 bg-yellow-100 border border-yellow-400 p-3 rounded">
          Waiting for <strong><%= @waitingForInvitee.name %></strong> to accept the game...
        </div>
        <div>
          <button
            class="bg-green-500 text-white px-3 py-1 rounded hover:bg-green-600 text-sm"
            phx-click="cancel_invite"
            phx-value-user="">
            Cancel the Invite
          </button>
        </div>
      <% end %>

      <%= if @inviterWaitingForMe do %>
        <div class="p-4 border rounded flex items-center justify-between shadow-sm">
          <div><%= @inviterWaitingForMe.name %></div>
          <button
            class="bg-green-500 text-white px-3 py-1 rounded hover:bg-green-600 text-sm"
            phx-click="accept_invite"
            phx-value-inviter={Jason.encode!(@inviterWaitingForMe)}>
            Accept Invite
          </button>
          <button
            class="bg-orange-500 text-white px-3 py-1 rounded hover:bg-orange-600 text-sm"
            phx-click="reject_invite"
            phx-value-user="">
            Reject the Invite
          </button>
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

  def get_game(%{connect_four_game: game} = _assigns, _inviter) do
    game
  end
  def get_game(assigns, %{"id" => user_id} = _inviter) do
    game_id = UUID.uuid1()
    ConnectFour.new_game(game_id, assigns.current_user.id, user_id)
  end

  defp getWaitingForInvitee(socket) do
    %{pending: pending, accepted: _accepted} = Invites.get_state()
    case Map.fetch(pending, Integer.to_string(socket.assigns.current_user.id)) do
      {:ok, [uid]} ->
          normalizeUser(Accounts.get_user!(uid))
      :error -> nil
    end
  end

  defp getInviterWaitingForMe(socket) do
    %{pending: pending, accepted: _accepted} = Invites.get_state()
    pending
    |> Enum.find(fn {_key, list} -> to_string(socket.assigns.current_user.id) in list end)
    |> case do
      {uid, _} -> normalizeUser(Accounts.get_user!(uid))
      nil -> nil  # not found
    end
  end

  defp maybe_assign_user_id(socket) do
    case socket.assigns[:current_user] do
      %Accounts.User{id: user_id} -> assign(socket, :user_id, user_id)
      _ -> socket
    end
  end

  defp broadcastUpdateUIStates() do
    Phoenix.PubSub.broadcast_from!(PubSub, self(), @game_invite_topic, %Broadcast{
      topic: @game_invite_topic,
      event: @update_ui_state_event,
      payload: nil
    })
  end

  # defp sendJoinToGameInvite(game_id) do
  #   Phoenix.PubSub.broadcast_from!(PubSub, self(), @game_invite_topic, %Broadcast{
  #     topic: @game_invite_topic,
  #     event: @game_join_event,
  #     payload: %{game_id: game_id}
  #   })
  # end

  def shouldSwitchToPlayRoute(%{accepted: accepted} = invites_state, socket) do
    Enum.find(accepted, fn {{u1, u2}, game_id} -> to_string(socket.assigns.current_user.id) in [u1,u2] and game_id != nil end)
  end

  # defp shouldResetWaitingFlags?(_leaves, nil, nil), do: false
  # defp shouldResetWaitingFlags?(leaves, nil, %{id: user_id} = _inviterWaitingForMe) do
  #   # if inviter left connect_four lobby need to reset waiting flags
  #   Map.has_key?(leaves, Integer.to_string(user_id))
  # end
  # defp shouldResetWaitingFlags?(leaves, %{id: user_id} = _waitingForInvitee, nil) do
  #   # if invitee left connect_four lobby need to reset waiting flags
  #   Map.has_key?(leaves, Integer.to_string(user_id))
  # end

  defp normalizeUser(%Hangman2.Accounts.User{} = user) do
    Map.delete(Map.from_struct(user), :__meta__)
  end
  defp normalizeUser(%{} = user), do: user
end
