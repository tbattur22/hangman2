defmodule HangmanWeb.Live.ConnectFour.GameLiveViewTest do
  use Hangman2Web.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user  # Provided by generated Phoenix auth helpers

  test "renders correctly", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/connect_four")

    assert html =~ "Connect Four Lobby"
    assert render(view) =~ "Available Users"
  end

end
