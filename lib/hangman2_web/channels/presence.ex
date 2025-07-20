defmodule Hangman2Web.Presence do
  use Phoenix.Presence,
    otp_app: :hangman2,
    pubsub_server: Hangman2.PubSub
end
