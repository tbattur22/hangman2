defmodule Hangman2Web.PageController do
  use Hangman2Web, :controller
  alias Hangman2.Accounts

  # def home(%{assigns: %{ user_token: token }} = conn, _params) do
  # user_token = get_session(conn, token)

  # # use the token as needed
  # IO.inspect(user_token, label: "User token")
  # user = user_token && Accounts.get_user_by_session_token(user_token)
  # signed_token =
  #   if user do
  #     Phoenix.Token.sign(Hangman2Web.Endpoint, "user auth to play game", user.id)
  #   end
  # IO.inspect(signed_token, label: "Page_controller:home: signed token")

  #   conn
  #   |> assign(:user_token, signed_token)
  #   |> assign(:user_id, user.id)
  #   |> render(:home, layout: false)
  # end

  def home(%{assigns: %{user_token: _}} = conn, _params) do
    IO.inspect(conn, label: "Page_controller:home:conn with token")
    user_token = get_session(conn, :user_token)
    IO.inspect(user_token, label: "User token")

    user = user_token && Accounts.get_user_by_session_token(user_token)

    signed_token =
      if user do
        Phoenix.Token.sign(Hangman2Web.Endpoint, App.Constants.user_token_salt, user.id)
      end

    IO.inspect(signed_token, label: "Page_controller:home: signed token")

    conn
    |> assign(:user_token, signed_token)
    |> assign(:user_id, (if user, do: user.id, else: nil))
    |> render(:home, layout: false)
  end

  def home(conn, _params) do
    IO.inspect(conn, label: "Page_controller:home:conn No token")
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end
end
