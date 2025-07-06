defmodule Hangman2.Repo do
  use Ecto.Repo,
    otp_app: :hangman2,
    adapter: Ecto.Adapters.Postgres
end
