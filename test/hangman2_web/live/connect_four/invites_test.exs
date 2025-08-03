defmodule HangmanWeb.Live.ConnectFour.InvitesTest do
  use Hangman2Web.ConnCase, async: true
  alias Hangman2Web.Live.ConnectFour.Invites

  setup do
    :sys.replace_state(Hangman2Web.Live.ConnectFour.Invites, fn _ -> %{pending: %{}, accepted: %{}} end)
    :ok
  end

  describe "Invites GenServer should work correctly" do
    test "Confirm that Invites server has already started and running" do
        assert Process.whereis(Hangman2Web.Live.ConnectFour.Invites)
        |> Process.alive?()
    end

    test "invite and accept works as expected" do
      pid = Process.whereis(Hangman2Web.Live.ConnectFour.Invites)
      assert Process.alive?(pid) == true

      u1 = "3"
      u2 = "2"
      game_id = "game-123456"

      :ok = Invites.invite(u1, u2)
      # %{pending: %{"3" => ["2"]}, accepted: %{}} = Invites.get_state()
      state = Invites.get_state()
      assert state.pending == %{"3" => ["2"]}
      assert state.accepted == %{}


      :ok = Invites.accept(u1, u2, game_id)
      state = Invites.get_state()
      assert state.pending == %{}
      assert state.accepted == %{{"3", "2"} => game_id}
      gameId = Invites.get_game_id(u1, u2)
      assert gameId == game_id

      # two users logged in and invited and accepted each other
      presence = %{
        "2" => %{metas: [%{user_id: 2, phx_ref: "GFYwFqYap2gB7itF", user_name: "Nyamka"}]},
        "3" => %{metas: [%{user_id: 3, phx_ref: "GFYwBj3Gs4cB7gsB", user_name: "Battur Tugsgerel"}]}
      }
      available_users = Invites.get_available_users_to_invite(presence)
      assert Enum.empty?(available_users)

      presence = %{
        "1" => %{metas: [%{user_id: 1, phx_ref: "GFYwFqYap2gB7asH", user_name: "User 1"}]},
        "2" => %{metas: [%{user_id: 2, phx_ref: "GFYwFqYap2gB7itF", user_name: "Nyamka"}]},
        "3" => %{metas: [%{user_id: 3, phx_ref: "GFYwBj3Gs4cB7gsB", user_name: "Battur Tugsgerel"}]}
      }
      available_users = Invites.get_available_users_to_invite(presence)
      assert available_users == ["1"]

    end

    test "confirm Invites state with multiple users and invites and accepts" do
      u1 = "3"
      u2 = "2"
      u3 = "4"
      u4 = "6"
      game_id = "game-12345678"
      game_id2 = "game-12345678910"

      :ok = Invites.invite(u1, u2)
      state = Invites.get_state()
      assert state.pending == %{"3" => ["2"]}
      assert state.accepted == %{}

      :ok = Invites.invite(u3, u4)
      state = Invites.get_state()
      assert state.pending == %{"3" => ["2"], "4" => ["6"]}
      assert state.accepted == %{}

      :ok = Invites.accept(u1, u2, game_id)
      state = Invites.get_state()
      assert state.pending == %{"4" => ["6"]}
      assert state.accepted == %{{"3", "2"} => game_id}
      gameId = Invites.get_game_id(u1, u2)
      assert gameId == game_id

      :ok = Invites.accept(u3, u4, game_id2)
      state = Invites.get_state()
      assert state.pending == %{}
      assert state.accepted == %{{"3", "2"} => game_id, {"4", "6"} => game_id2}
      gameId2 = Invites.get_game_id(u3, u4)
      assert gameId2 == game_id2
    end

    test "get_available_users_to_invite works correctly" do
      u1 = "3"
      u2 = "2"
      game_id = "game-12345678"

      presence = %{
        "2" => %{metas: [%{user_id: 2, phx_ref: "GFYwFqYap2gB7itF", user_name: "Nyamka"}]},
        "3" => %{metas: [%{user_id: 3, phx_ref: "GFYwBj3Gs4cB7gsB", user_name: "Battur Tugsgerel"}]}
      }
      available_users = Invites.get_available_users_to_invite(presence)
      assert MapSet.new(available_users) == MapSet.new([u1,u2])

      :ok = Invites.invite(u1, u2)
      state = Invites.get_state()
      assert state.pending == %{"3" => ["2"]}
      assert state.accepted == %{}

      presence = %{
        "2" => %{metas: [%{user_id: 2, phx_ref: "GFYwFqYap2gB7itF", user_name: "Nyamka"}]},
        "3" => %{metas: [%{user_id: 3, phx_ref: "GFYwBj3Gs4cB7gsB", user_name: "Battur Tugsgerel"}]}
      }
      available_users = Invites.get_available_users_to_invite(presence)
      assert Enum.empty?(available_users)


      :ok = Invites.accept(u1, u2, game_id)
      state = Invites.get_state()
      assert state.pending == %{}
      assert state.accepted == %{{"3", "2"} => game_id}

      presence = %{
        "4" => %{metas: [%{user_id: 4, phx_ref: "GFYwFqYap2gB7itF", user_name: "User 1"}]},
        "5" => %{metas: [%{user_id: 5, phx_ref: "GFYwBj3Gs4cB7gsB", user_name: "User 2"}]}
      }
      available_users = Invites.get_available_users_to_invite(presence)
      assert MapSet.new(available_users) == MapSet.new(["4","5"])

    end
  end
end
