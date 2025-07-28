defmodule Hangman2Web.Live.ConnectFour.Play do
alias Hangman2Web.Live.ConnectFour.Invites
  use Hangman2Web, :live_view
  require Logger
  alias Hangman2.Accounts
  alias Hangman2.PubSub
  alias Hangman2Web.Presence
  alias Phoenix.Socket.Broadcast

  @presence_topic "game:lobby" # Define the topic
  @game_play_topic "game:play"
  @game_restart_event "pending_restart"
  @game_exit_event "pending_exit"

  @impl true
  def mount(%{"game_id" => game_id} = params, session, socket) do
    Logger.info("Play:mount():params:#{inspect(params)}, session: #{inspect(session)}, and socket: #{inspect(socket)}")

    socket =
      assign_new(socket, :current_user, fn ->
        user_token = session["user_token"]
        Accounts.get_user_by_session_token(user_token)
      end)

    if connected?(socket) do
      Logger.debug("Play:connectedSocket: assigns #{inspect(socket.assigns)}")
      Phoenix.PubSub.subscribe(ConnectFour.PubSub, "game:#{game_id}")
      Phoenix.PubSub.subscribe(PubSub, @presence_topic)
      Phoenix.PubSub.subscribe(PubSub, @game_play_topic)

      case ConnectFour.game_state(game_id) do
        {:ok, game} ->
          Logger.info("Play:connected:game_state #{inspect(game)}")
          red_user = Accounts.get_user!(game.players.red)
          yellow_user = Accounts.get_user!(game.players.yellow)

         {:ok,
           assign(socket,
            game_over: false,
            game_id: game_id,
            game: Map.from_struct(game),
            board: game.board,
            red_player: red_user,
            yellow_player: yellow_user
          )}

        {:error, reason} ->
          Logger.error("Play:connected:game_state failed to obtain game state, reason: #{reason}")
          {:ok,
            socket
            |> put_flash(:error, "Game not found.")
            |> push_navigate(to: ~p"/connect_four")
          }
      end
    else
      {:ok, socket}
    end
  end

  def render(%{current_user: current_user, game: game, board: _board} = assigns) do
    Logger.debug("Play:render with board: assigns #{inspect(assigns)}")
    can_move? = current_user.id == ConnectFour.Impl.Game.get_uid_by_player(game.players, game.current_player)

    assigns = Map.put(assigns, :can_move?, can_move?)

    ~H"""
      <%= if match?({:win, _}, @game.game_state) do %>
        <% {:win, winner} = @game.game_state %>
        <div class="game-result" style="margin-bottom: 12px; font-weight: bold;">
          <%= if winner == :red and @red_player.id == @current_user.id do %>
            🏆 You (Red) won!
          <% else %>
            <%= if winner == :yellow and @yellow_player.id == @current_user.id do %>
              🏆 You (Yellow) won!
            <% else %>
              💥 <%= String.capitalize(to_string(winner)) %> wins!
            <% end %>
          <% end %>
        </div>
      <% else %>
        <%= if @game.game_state == :draw do %>
          <div class="game-result" style="margin-bottom: 12px; font-weight: bold;">
            🤝 It's a draw!
          </div>
        <% end %>
      <% end %>

      <%= if @game_over do %>
        <div style="margin-top: 16px;">
          <button phx-click="restart_game" class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700">🔄 Restart Game</button>
          <button phx-click="exit_game" class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700" style="margin-left: 8px;">🚪 Exit</button>
        </div>
      <% end %>


      <div class="players-info" style="margin-bottom: 16px;">
        <p><strong>🔴 Red:</strong> <%= @red_player.name %></p>
        <p><strong>🟡 Yellow:</strong> <%= @yellow_player.name %></p>

        <%= if !@game_over do %>
          <%= if @game.current_player == :red do %>
            <%= if @red_player.id == @current_user.id do %>
              <p>It is your turn to drop 🔴</p>
            <% else %>
              <%= if @yellow_player.id == @current_user.id do %>
                <p>It is <%= @red_player.name %>'s turn to drop 🔴</p>
              <% else  %>
                <p>It is your turn to drop 🟡</p>
              <% end %>
            <% end %>
          <% else %>
            <%= if @yellow_player.id == @current_user.id do %>
              <p>It is your turn to drop 🟡</p>
            <% else %>
              <%= if @red_player.id == @current_user.id do %>
                <p>It is <%= @yellow_player.name %>'s turn to drop 🟡</p>
              <% else %>
                <p>It is your turn to drop 🔴</p>
              <% end %>
            <% end %>
          <% end %>
        <% end %>
      </div>

      <div class="connect-four-board" style="display: grid; grid-template-rows: repeat(6, 50px); grid-template-columns: repeat(7, 50px); gap: 4px;">
        <%= for row_index <- Enum.reverse(0..5) do %> <!-- From bottom row to top -->
          <%= for col_index <- 0..6 do %>
            <% cell = Enum.at(Enum.at(@board, col_index), row_index) %>
            <% is_top_cell = row_index == 5 %>
            <% is_clickable = row_index == 5 and @can_move? %>
            <% style = "width: 50px; height: 50px; border: 1px solid #ccc; display: flex; align-items: center; justify-content: center; background-color: white;" <> if is_clickable, do: " cursor: pointer;", else: "" %>
            <div
              class="cell"
              style={style}
              title={if is_top_cell and is_clickable, do: "Click to drop"}
              {if is_clickable, do: ["phx-click": "drop_piece", "phx-value-col": col_index], else: []}
            >
              <%= case cell do %>
                  <% :red -> %>
                    <div style="width: 80%; height: 80%; background-color: red; border-radius: 50%;"></div>
                  <% :yellow -> %>
                    <div style="width: 80%; height: 80%; background-color: yellow; border-radius: 50%;"></div>
                  <% nil -> %>
                    <div style="width: 80%; height: 80%; background-color: lightgray; border-radius: 50%;"></div>
                <% end %>
            </div>
          <% end %>
        <% end %>
      </div>
    """
  end


  def render(assigns) do
    ~H"""
    """
  end


  @impl true
  def handle_info(%Broadcast{topic: @game_play_topic = topic, event: @game_restart_event, payload:  %{game_id: game_id}} = _event, socket) when game_id == socket.assigns.game_id do
    Logger.debug("Play:Received #{inspect(@game_restart_event)}: topic: #{inspect(topic)}, payload: game_id: #{game_id}")

    {:noreply, push_navigate(socket, to: ~p"/connect_four/game/#{game_id}")}
  end
  @impl true
  def handle_info(%Broadcast{topic: @game_play_topic = topic, event: @game_restart_event, payload:  %{game_id: _game_id}} = _event, socket), do: {:noreply, socket}


  def handle_info(%Broadcast{topic: @game_play_topic = topic, event: @game_exit_event, payload:  %{game_id: game_id, flash_msg: flash_msg}} = _event, socket) when game_id == socket.assigns.game_id do
    Logger.debug("Play:Received #{inspect(@game_exit_event)}: topic: #{inspect(topic)}, payload: game_id: #{game_id}")

    {:noreply,
      socket
      |> put_flash(:info, flash_msg)
      |> push_navigate(to: ~p"/connect_four")
    }
  end
  def handle_info(%Broadcast{topic: @game_play_topic = topic, event: @game_exit_event, payload:  %{game_id: _game_id, flash_msg: _flash_msg}} = _event, socket), do: {:noreply, socket}

  def handle_info(%Broadcast{event: "presence_diff", payload: %{joins: _joins, leaves: _leaves}} = _event, socket) do
    # Logger.debug("Play:Presence_diff event:current_user:#{socket.assigns.current_user.id}, pid: #{inspect(self())} joins:#{inspect(joins)}, leaves: #{inspect(leaves)}")

    {:noreply, socket}
  end


  @impl true
  def handle_info({:make_move, updated_game}, socket) do
    game_over =
    case updated_game.game_state do
      {:win, _player} -> true
      :draw -> true
      _ -> false
    end

    {:noreply,
    assign(socket,
      game: Map.from_struct(updated_game),
      board: updated_game.board,
      game_over: game_over
    )}
  end


  def handle_event("drop_piece", %{"col" => col_str}, socket) do
    col = String.to_integer(col_str)
    game_id = socket.assigns.game_id
    user = socket.assigns.current_user

    case ConnectFour.game_pid(game_id) do
      {:ok, pid} ->
        case ConnectFour.make_move(pid, user.id, col) do
          %ConnectFour.Impl.Game{} = updated_game ->
            {:noreply,
            assign(socket,
              game: Map.from_struct(updated_game),
              board: updated_game.board
            )}

          val ->
            # Optionally show flash or ignore
            IO.inspect(val, label: "Drop piece error")
            {:noreply, socket}
        end

      {:error, "No server process found for game id " <> game_id} ->
        sendExitGame(game_id, "Game session has expired!")

        {:noreply,
          socket
          |> put_flash(:info, "Game session has expired!")
          |> push_navigate(to: ~p"/connect_four")
        }

      _val ->
        {:noreply,
          socket
          |> put_flash(:error, "Oops! Unexpected error!")
          |> push_navigate(to: ~p"/connect_four")
        }
    end
  end

  @impl true
  def handle_event("restart_game", _params, socket) do
    case ConnectFour.game_pid(socket.assigns.game_id) do
      {:ok, pid} ->
        restarted_game = ConnectFour.play_again(pid)

        sendRestartGame(socket.assigns.game_id)

        {:noreply,
          assign(socket,
            game: Map.from_struct(restarted_game),
            board: restarted_game.board,
            game_over: false
        )}

      {:error, reason} ->
          Logger.error("Could not get game pid for game id #{socket.assigns.game_id} reason: #{inspect(reason)}")
          Invites.remove_user(to_string(socket.assigns.current_user.id))

        {:noreply,
         socket
          |> put_flash(:error, "Oops! Unexpected error, could not get game_id, exiting")
          |> push_navigate(to: ~p"/connect_four")
        }
    end
  end

  @impl true
  def handle_event("exit_game", _params, socket) do
    Invites.remove_user(to_string(socket.assigns.current_user.id))
    sendExitGame(socket.assigns.game_id, "Game exit clicked")

    {:noreply, push_navigate(socket, to: ~p"/connect_four")}
  end

  def handle_event(event, params, socket) do
    IO.inspect({:unhandled_event, event, params})
    {:noreply, socket}
  end

  defp sendRestartGame(game_id) do
    Phoenix.PubSub.broadcast_from!(PubSub, self(), @game_play_topic, %Broadcast{
      topic: @game_play_topic,
      event: @game_restart_event,
      payload: %{game_id: game_id}
    })
  end
  defp sendExitGame(game_id, flash_msg) do
    Phoenix.PubSub.broadcast_from!(PubSub, self(), @game_play_topic, %Broadcast{
      topic: @game_play_topic,
      event: @game_exit_event,
      payload: %{game_id: game_id, flash_msg: flash_msg}
    })
  end

end
