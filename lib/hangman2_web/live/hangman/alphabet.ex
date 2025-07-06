defmodule Hangman2Web.Live.Game.Alphabet do

  use Hangman2Web, :live_component

  def mount(socket) do
    letters = (?a..?z)|> Enum.map(&<< &1 :: utf8 >>)

    {:ok, assign(socket, :letters, letters)}
  end

  def render(assigns) do
    ~H"""
      <div class="alphabet p-4 mb-[10%] flex flex-wrap justify-center gap-y-2 gap-x-4 text-[150%]">
        <%= for letter <- assigns.letters do %>
          <div phx-click="make_move" phx-value-key={letter} class={"one-letter #{classOf(letter, assigns.tally)}"}>
            <%= letter %>
          </div>
        <% end %>
      </div>
    """
  end

  defp classOf(letter, tally) do
    cond do
      Enum.member?(tally.letters, letter) -> "text-[#88bb88]"
      Enum.member?(tally.used, letter) -> "text-[#bb8888]"
      true -> ""
    end
  end
end
