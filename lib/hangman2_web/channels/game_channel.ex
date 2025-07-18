defmodule Hangman2Web.GameChannel do
  use Hangman2Web, :channel
  alias Logger

  @impl true
  def join(
    "game:lobby",
    %{"user_id" => req_user_id} = _payload, socket = %{assigns: %{user_id: user_id}}
  ) do
    if req_user_id == to_string(user_id) do
      {:ok, socket}
    else
      Logger.error("#{__MODULE__} failed #{req_user_id} != #{user_id}")
      {:error, %{reason: "unauthorized"}}
    end
  end


  # def join("game:lobby", payload, socket) do
  #   if authorized?(payload, socket) do
  #     {:ok, socket}
  #   else
  #     {:error, %{reason: "unauthorized"}}
  #   end
  # end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (game:lobby).
  @impl true
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  # defp authorized?(%{"user_id" => iser_id} = _payload, $) do

  #   true
  # end
end
