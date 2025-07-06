defmodule Hangman2Web.Live.Game do

  use Hangman2Web, :live_view

  alias Hangman2.Accounts

  def mount(_params, sessions, socket) do
    # assign_new will use existing assign from static render if present,
    # and only run the function when needed.
    socket =
      assign_new(socket, :current_user, fn ->
        user_token = sessions["user_token"]
        Accounts.get_user_by_session_token(user_token)
      end)

    if (connected?(socket)) do
      game = get_game(socket.assigns)
      tally = Hangman.tally(game)

      {:ok, socket|> assign(%{game: game, tally: tally})}
    else
      {:ok, socket}
    end
  end

  def handle_event("make_move", %{ "key" => key }, socket) do
    if String.match?(key, ~r/^\p{L}$/u) do
      tally = Hangman.make_move(socket.assigns.game, key)
      { :noreply, assign(socket, :tally, tally) }
    else
      { :noreply, socket }
    end
  end

  def handle_event("play_again", _params, socket) do
    tally = Hangman.play_again(socket.assigns.game)
    { :noreply, assign(socket, :tally, tally) }
  end

  def render (%{game: _game, tally: _tally} = assigns) do
    ~H"""
    <div class="game-holder h-fit grid place-items-center md:flex" phx-window-keyup="make_move">
      <div class="mb-1">
        <.live_component module={__MODULE__.Figure} id="1" tally={assigns.tally} />
      </div>
      <div>
        <.live_component module={__MODULE__.Alphabet} id="2" tally={assigns.tally} />
        <.live_component module={__MODULE__.WordsSoFar} id="3" tally={assigns.tally} game={assigns.game} />
      </div>
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

  def get_game(%{game: game} = _assigns) do
    game
  end
  def get_game(assigns) do
    Hangman.new_game(assigns.current_user.id)
  end
end
