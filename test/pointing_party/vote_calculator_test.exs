defmodule PointingParty.VoteCalculatorTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias PointingParty.VoteCalculator

  describe "calculate_votes/1" do
    setup do
      # Our user data looks like this:
      #
      #   %{
      #     "michael" => %{metas: [%{points: 5}]}
      #     "sophie" => %{metas: [%{points: 3}]}
      #   }
      #
      #
      # Fix the generator below. It should return a data structure like the one above.
      # Hint: use fixed_map/1, member_of/1, list_of/2, string/2, and nonempty/1.
      points_map = fixed_map(%{points: integer()})
      metas_map = fixed_map(%{metas: nonempty(list_of(points_map, length: 1))})
      users_map = map_of(string(:alphanumeric), metas_map)

      [user_generator: users_map]
    end

    property "calculated vote is a list or an integer", %{user_generator: user_generator} do
      check all users <- user_generator,
                _ = IO.inspect(users),
                {_event, winner} = VoteCalculator.calculate_votes(users),
                max_runs: 20 do
        # We'll assert something here
      end
    end
  end
end
