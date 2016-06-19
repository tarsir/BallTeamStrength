defmodule TeamStrength.Team do
  defstruct team_name: "", strength: :nil

  defmacro team?(team_name) do
    quote do: unquote(team_name) != ""
  end

  def add_team(team_name, team_list) when is_binary(team_name) do
    new_team = %TeamStrength.Team{team_name: team_name, strength: 0}
    {:ok, [new_team] ++ team_list}
  end

  def team_in_list?(team_name, team_list) when is_binary(team_name) and is_list(team_list) do
    Enum.any?(team_list, fn(x) -> x.team_name == team_name end)
  end

  def update_team_strength(team_name, new_strength, team_list) when is_binary(team_name) and is_list(team_list) and is_number(new_strength) do
    {match, rest} = Enum.partition(team_list, fn(x) -> x.team_name == team_name end)
    match = %TeamStrength.Team{team_name: hd(match).team_name, strength: new_strength}
    [match] ++ rest
  end

  def find_team(team_name, team_list) when is_binary(team_name) and is_list(team_list) do
    cond do
      [] == team_list ->
        {:error, "Not found in list"}
      [h|t] = team_list ->
        if h.team_name == team_name do
          {:ok, h}
        else
          if [] == t do
            {:error, "Not found in list"}
          else
            find_team(team_name, t)
          end
        end
      true ->
        {:error, "what is this"}
    end
  end

end

defmodule TeamStrength.TeamGame do
  alias TeamStrength.Team
  defstruct team: Team, score: 0
end

defmodule TeamStrength.GameOutcome do
  alias TeamStrength.TeamGame, as: TeamGame
  defstruct winners: TeamGame, losers: TeamGame, tie: false

  def build_results_map(teams_w_score) when is_binary(teams_w_score) do
    list = String.split(teams_w_score, ",")
    list = Enum.map(list, fn(x) -> String.strip(x) end)
    if Enum.count(list) == 4 do
      # how can I make these next two lines cleaner :(
      team_one = %TeamGame{team: hd(list), score: hd(tl(list)) |> Integer.parse |> elem(0)}
      team_two = %TeamGame{team: hd(tl(tl(list))), score: List.last(list) |> Integer.parse |> elem(0)}
      cond do
        team_one.score > team_two.score ->
          %TeamStrength.GameOutcome{winners: team_one, losers: team_two}
        team_one.score == team_two.score ->
          %TeamStrength.GameOutcome{winners: team_two, losers: team_one, tie: true}
        true ->
          %TeamStrength.GameOutcome{winners: team_two, losers: team_one}
      end
    end
  end
end

defmodule TeamStrength.Main do
  defstruct all_teams: []
  alias TeamStrength.GameOutcome, as: Outcome
  alias TeamStrength.Team, as: Team
  @learning_rate 0.4
  @learning_decel 0.15

  defp get_from_team_list(team_name, team_list) when is_binary(team_name) and is_list(team_list) do
    res = Team.find_team(team_name, team_list)
    case res do
      {:ok, team} ->
        {:ok, team, team_list}
      {:error, "Not found in list"} ->
        {:ok, team_list} = Team.add_team(team_name, team_list)
        {:ok, hd(team_list), team_list}
      _ ->
        {:error, "What is happening"}
    end
  end

  defp calc_delta(%Outcome{} = game, team_list) when is_list(team_list) do
    if game.tie do
      team_list
    else
      {winners, losers} = {game.winners, game.losers}
      actual_delt = winners.score - losers.score
      with {:ok, win_team, team_list} <- get_from_team_list(winners.team, team_list),
        {:ok, lose_team, team_list} <- get_from_team_list(losers.team, team_list),
        expected_delta <- win_team.strength - lose_team.strength,
        updated_loser_str <- -1 * @learning_rate * (actual_delt - expected_delta) + lose_team.strength,
        updated_winner_str <- @learning_rate * (actual_delt - expected_delta) + win_team.strength,
        updated_winner_list <- Team.update_team_strength(win_team.team_name, updated_winner_str, team_list),
        do: 
          Team.update_team_strength(lose_team.team_name, updated_loser_str, updated_winner_list)
    end
  end

  def get_game_data(data_file \\ "leagues_NBA_2016_games_games_playoffs.csv")
  def get_game_data(data_file) do
    body_split = String.split(File.read!(data_file), "\n")        
    [ _, col_data ] = [ hd(body_split), tl(body_split)]
    Enum.map(col_data, fn (x) -> if x != "" do Outcome.build_results_map(x) end end)
  end

  def calculate_strengths(outcomes \\ get_game_data -- [:nil])
  def calculate_strengths(outcomes) when is_list(outcomes) do
    team_list = []
    Enum.reduce(outcomes, [], fn(x, acc) -> calc_delta(x, acc) end)
  end

  def a do
    calculate_strengths
  end
end
