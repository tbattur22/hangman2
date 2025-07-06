defmodule Hangman2Web.Live.Game.WordsSoFar do

  use Hangman2Web, :live_component

  @states %{
    already_used: "You already picked that letter",
    bad_guess: "That's not in the word",
    good_guess: "Good guess!",
    initializing: "Type or click on your first guess",
    lost: "Sorry, you lost...",
    won: "You won!"
  }

  def mount(socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="grid place-items-center">
      <div class="words-so-far text-[150%]">
        <div>Turns left: <%= @tally.turns_left %></div>
        <div class={game_state_style(@tally.game_state)}><%= state_name(@tally.game_state) %></div>
        <div>
          <%= maybe_reveal_word(@game, @tally) %>
        </div>
      </div>
      <div class="letters flex p-4">
        <%= for ch <- @tally.letters do %>
          <div class={"one-letter mr-4 text-[150%] #{if ch !== "_", do: "correct font-bold", else: ""}"}>
            <%= ch %>
          </div>
        <% end %>
      </div>
      <div>
        <%= if @tally.game_state in [:lost, :won] do %>
          <button phx-click="play_again" type="button" class="text-white bg-blue-700 hover:bg-blue-800 focus:outline-none focus:ring-4 focus:ring-blue-300 font-medium rounded-full text-sm px-5 py-2.5 text-center me-2 mb-2 dark:bg-blue-600 dark:hover:bg-blue-700 dark:focus:ring-blue-800">Play again</button>
        <% end %>
      </div>
    </div>
    """
  end

  defp state_name(state) do
    @states[state] || "Unknown state"
  end

  defp game_state_style(:good_guess), do: "text-green-700"
  defp game_state_style(:bad_guess), do: "text-red-700"
  defp game_state_style(:lost), do: "text-red-700"
  defp game_state_style(:won), do: "text-green-700"
  defp game_state_style(_), do: "text-black-400"

  defp maybe_reveal_word(game, %{game_state: :lost}) do
    word =
      Hangman.guessed_word(game)
      |>Enum.join(" ")
    "The word is: <" <> word <> ">"
  end
  defp maybe_reveal_word(_game, _tally), do: ""
end
