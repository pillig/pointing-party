defmodule PointingPartyWeb.CardLive do
  use Phoenix.LiveView
  @topic "pointing_party"
  alias PointingParty.{Card, VoteCalculator}
  alias PointingPartyWeb.Endpoint
  alias PointingPartyWeb.Presence


  def render(assigns) do
    Phoenix.View.render(PointingPartyWeb.CardView, "index.html", assigns)

  end

  def mount(%{username: username}, socket) do
    Endpoint.subscribe(@topic)
    {:ok, _} = Presence.track(self(), @topic, username, %{points: nil, username: username})
    {:ok, assign(socket, initial_state(username))}
  end

  ## Helper Methods ##
  def handle_event("start_party", _value, socket) do
    [first_card | remaining_cards ] = Card.cards()
    payload = %{card: first_card, remaining_cards: remaining_cards}
    Endpoint.broadcast(@topic, "party_started", payload)
    {:noreply, socket}
  end

  def handle_event("vote_submit", %{"points" => points}, socket) do
    Presence.update(self(), @topic, socket.assigns.username, %{points: points})
    if everyone_voted?() do
      {outcome, point_tally} = VoteCalculator.calculate_votes(Presence.list(@topic))
      Endpoint.broadcast(@topic, "votes_calculated", %{outcome: outcome, point_tally: point_tally})

    end
    {:noreply, socket}
  end

  def handle_event("next_card", winning_points, socket) do
    Endpoint.broadcast(@topic, "next_card", %{winning_points: winning_points})
    {:noreply, socket}
  end

  def handle_info(%{event: "presence_diff", payload: %{joins: joins, leaves: []}}, socket) do
    Endpoint.broadcast(@topic, "joiners", %{joiners: Map.keys(joins)})
    {:noreply, assign(socket, users: Presence.list(@topic))}
  end

  def handle_info(%{event: "presence_diff", payload: %{joins: joins, leaves: leaves}}, socket) do
    # %{"sophie" => [metas: %{username: username}]}
    Endpoint.broadcast(@topic, "leavers", %{leavers: Map.keys(leaves)})
    {:noreply, assign(socket, users: Presence.list(@topic))}
  end

  # def handle_info(%{event: "presence_diff"}, socket) do
  #   {:noreply, assign(socket, users: Presence.list(@topic))}
  # end

  def handle_info(%{event: "votes_calculated", payload: %{outcome: outcome, point_tally: point_tally}}, socket) do
    updated_socket =
      socket
      |> assign(:outcome, outcome)
      |> assign(:point_tally, point_tally)
    {:noreply, updated_socket}
  end

  def handle_info(%{event: "next_card", payload: %{winning_points: winning_points}, topic: @topic}, socket) do
    Presence.update(self(), @topic, socket.assigns.username, %{points: nil})
    updated_socket = save_vote_next_card(winning_points, socket)
    {:noreply, updated_socket}
  end

  def handle_info(%{
        event: "party_started",
        payload: %{card: card, remaining_cards: remaining_cards},
        topic: @topic}, socket) do
      {:noreply, assign(socket,
                  current_card: card,
                  remaining_cards: remaining_cards,
                  is_pointing: true)}
  end

  def handle_info(%{event: "joiners", payload: %{joiners: joiners}, topic: @topic}, socket) do
    {:noreply, assign(socket, joiners: joiners)}
  end

  def handle_info(%{event: "leavers", payload: %{leavers: leavers}, topic: @topic}, socket) do
    {:noreply, assign(socket, leavers: leavers)}
  end

  defp initial_state(username) do
    [
      current_card: nil,
      outcome: nil,
      joiners: [],
      leavers: [],
      is_pointing: false,
      remaining_cards: [],
      completed_cards: [],
      point_tally: nil,
      users: [],
      username: username
    ]
  end

  def everyone_voted?() do

    @topic
    |> Presence.list()
    |> Enum.map(fn {_username, %{metas: [%{points: points}]}} -> points end)
    |> Enum.all?(&(&1))
  end

  defp save_vote_next_card(points, socket) do
    latest_card =
      socket.assigns
      |> Map.get(:current_card)
      |> Map.put(:points, points)

    {next_card, remaining_cards} =
      socket.assigns
      |> Map.get(:remaining_cards)
      |> List.pop_at(0)

    socket
    |> assign(:remaining_cards, remaining_cards)
    |> assign(:current_card, next_card)
    |> assign(:outcome, nil)
    |> assign(:results, nil)
    |> assign(:completed_cards, [latest_card | socket.assigns[:completed_cards]])
  end
end
