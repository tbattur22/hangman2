defmodule Hangman2Web.Live.ConnectFour.Invites do
  use GenServer
  require Logger

  @type state :: %{
          pending: %{String.t() => [String.t()]},
          accepted: %{{String.t(), String.t()} => String.t()}
        }

  # --- Public API ---

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{
      pending: %{},
      accepted: %{}
    }, name: __MODULE__)
  end

  def invite(inviter, invitee) do
    GenServer.cast(__MODULE__, {:invite, to_string(inviter), to_string(invitee)})
  end

  def accept(inviter, invitee, game_id) do
    GenServer.cast(__MODULE__, {:accept, to_string(inviter), to_string(invitee), game_id})
  end

  def get_game_id(inviter, invitee) do
    GenServer.call(__MODULE__, {:get_game_id, to_string(inviter), to_string(invitee)})
  end

  def remove_user(user_id) do
    GenServer.cast(__MODULE__, {:remove_user, to_string(user_id)})
  end

  def get_available_users_to_invite(presence_map) do
    GenServer.call(__MODULE__, {:available_users, presence_map})
  end

  def finish_game(user1, user2) do
    GenServer.cast(__MODULE__, {:finish_game, to_string(user1), to_string(user2)})
  end

  def remove_from_accepted(user_id) do
    GenServer.cast(__MODULE__, {:remove_from_accepted, to_string(user_id)})
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def get_pid() do
    GenServer.call(__MODULE__, :get_pid)
  end

  # --- Callbacks ---

  @impl true
  def handle_call({:available_users, presence_map}, _from, state) do
    all_present_ids =
      presence_map
      |> Map.keys()

    users_in_games =
      state.accepted
      |> Map.keys()
      |> Enum.flat_map(fn {a, b} -> [a, b] end)
      |> MapSet.new()

    users_in_pending =
      state.pending
      |> Enum.flat_map(fn {inviter, invitees} -> [inviter | invitees] end)

    unavailable_ids =
      (MapSet.to_list(users_in_games) ++ users_in_pending)
      |> MapSet.new()

    available =
      all_present_ids
      |> Enum.reject(&MapSet.member?(unavailable_ids, &1))

    {:reply, available, state}
  end

  @impl true
  def handle_call({:get_game_id, inviter, invitee}, _from, state) do
    inviter = to_string(inviter)
    invitee = to_string(invitee)

    key = {inviter, invitee}
    game_id = Map.get(state.accepted, key) || Map.get(state.accepted, {invitee, inviter})
    {:reply, game_id, state}
  end

  @impl true
  def handle_call(:get_state, _from, state), do: {:reply, state, state}
  @impl true
  def handle_call(:get_pid, _from, state), do: {:reply, self(), state}

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_cast({:invite, inviter, invitee}, state) do
    inviter = to_string(inviter)
    invitee = to_string(invitee)
    Logger.info("Invites:handle_cast:invite: inviter:#{inviter}, invitee: #{invitee}, state: #{inspect(state)}")

    pending = Map.update(state.pending, inviter, [invitee], fn invitees ->
      [invitee | invitees] |> Enum.uniq()
    end)

    updated_state = %{state | pending: pending}
    Logger.info("Invites:handle_cast:invite: updated_state: #{inspect(updated_state)}")

    {:noreply, updated_state}
  end

  @impl true
  def handle_cast({:accept, inviter, invitee, game_id}, state) do
    inviter = to_string(inviter)
    invitee = to_string(invitee)

    Logger.info("Invites:handle_cast:accept: inviter:#{inviter}, invitee: #{invitee}, game_id: #{game_id}")
    key = {inviter, invitee}

    accepted = Map.put(state.accepted, key, game_id)

    pending =
      state.pending
      |> Map.update(inviter, [], fn invitees ->
        Enum.reject(invitees, &(&1 == invitee))
      end)
      |> Enum.reject(fn {_inviter, invitees} -> invitees == [] end)
      |> Map.new()

      updated_state = %{state | accepted: accepted, pending: pending}
      Logger.info("Invites:handle_cast:accept: updated_state: #{inspect(updated_state)}")
    {:noreply, updated_state}
  end

  @impl true
  def handle_cast({:remove_user, user_id}, state) do
    user_id = to_string(user_id)
    # Remove as inviter or invitee in pending
    pending =
      state.pending
      |> Enum.reduce(%{}, fn {inviter, invitees}, acc ->
        cond do
          inviter == user_id ->
            acc  # skip this inviter

          true ->
            filtered_invitees = Enum.reject(invitees, &(&1 == user_id))
            Map.put(acc, inviter, filtered_invitees)
        end
      end)
      |> Enum.reject(fn {_k, v} -> v == [] end)
      |> Map.new()

    # Remove accepted pairs that involve the user
    accepted =
      state.accepted
      |> Enum.reject(fn {{a, b}, _game_id} -> a == user_id or b == user_id end)
      |> Map.new()

    {:noreply, %{pending: pending, accepted: accepted}}
  end

  @impl true
  def handle_cast({:finish_game, user1, user2}, state) do
    user1 = to_string(user1)
    user2 = to_string(user2)

    accepted =
        state.accepted
        |> Map.drop([{user1, user2}, {user2, user1}])

    {:noreply, %{state | accepted: accepted}}
  end

  @impl true
  def handle_cast({:remove_from_accepted, user_id}, state) do
    user_id = to_string(user_id)

    accepted =
      state.accepted
      |> Enum.reject(fn {{a, b}, _game_id} ->
        a == user_id or b == user_id
      end)
      |> Enum.into(%{})

    {:noreply, %{state | accepted: accepted}}
  end

end
