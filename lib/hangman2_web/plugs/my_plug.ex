defmodule Hangman2Web.Plugs.MyPlug do
  import Plug.Conn

  @behaviour Plug

  def init(options) do
    # Initialize any options if needed.
    options
  end

  def call(conn, opts) do
    # Add user token to the connection if available
    if current_user = conn.assigns[:current_user] do
      token = Phoenix.Token.sign(conn, App.Constants.user_token_salt, current_user.id)
      assign(conn, :user_token, token)
    else
      conn
    end
  end
end
