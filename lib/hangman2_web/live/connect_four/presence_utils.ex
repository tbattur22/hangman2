defmodule Hangman2Web.Live.ConnectFour.PresenceUtils do
  alias Hangman2Web.Presence

  def unique_users(topic \\ "game:lobby") do
    Presence.list(topic)
    |> Enum.map(fn {user_id, %{metas: [meta | _]}} ->
      {user_id, meta}
    end)
  end
end
