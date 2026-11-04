extends Node
## Battle (autoload "Battle"). Match setup and results for the battle system:
##  - setup_match(): builds a Solo / Tournament / Clan War match against opponents of
##    exactly the player's rank (the Golden Rule), applies the map rule (both sides state a
##    preference; if they differ the system picks at random) and announces
##    "Your match is ready. Follow the markers to your portal. Good luck!"
##  - the city shows the portal marker while a match is pending; stepping through the Spire
##    gate loads the arena and SpireCombat runs the match from `pending`.
##  - finish(): pays Renown and Points per BattleData.MODES and keeps `last_result`.
## With no pending match the Spire runs as the open training ground.

signal match_ready(match: Dictionary)
signal match_cleared
signal match_finished(result: Dictionary)

var pending: Dictionary = {}
var last_result: Dictionary = {}
var history: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func has_pending() -> bool:
	return not pending.is_empty()


func mode_info(mode: String) -> Dictionary:
	return BattleData.MODES.get(mode, BattleData.MODES["solo"])


## Which tournament tiers the player may enter: only their own rank (document: you cannot
## enter tournaments meant for higher ranks).
func can_enter_tournament(tier: String) -> bool:
	return tier == RankManager.rank_letter()


## Clan members a leader may pick for a war at `tier`: online and exactly that rank.
func eligible_clan_members(tier: String) -> Array:
	var out: Array = []
	for m in BattleData.CLAN_MEMBERS:
		if m["online"] and m["rank"] == tier:
			out.append(m)
	return out


## Builds the match. `preferred_map` is the player's choice; `allies` are clan member names
## (clan war only, max 5 including the player); `opponent_class` optional for solo.
## `dry_run` builds and returns the match without making it pending or announcing it.
func setup_match(mode: String, preferred_map: String, allies: Array = [], seed_value := -1, dry_run := false) -> Dictionary:
	if seed_value >= 0:
		_rng.seed = seed_value
	var rank := RankManager.rank_letter()
	var info := mode_info(mode)
	var opp_pref: String = BattleData.MAPS[_rng.randi_range(0, BattleData.MAPS.size() - 1)]["id"]
	var map_id := preferred_map
	var map_rule := "both chose %s" % BattleData.map_by_id(preferred_map)["name"]
	if opp_pref != preferred_map:
		map_id = BattleData.MAPS[_rng.randi_range(0, BattleData.MAPS.size() - 1)]["id"]
		map_rule = "preferences differed (%s vs %s): system picked %s" % [BattleData.map_by_id(preferred_map)["name"], BattleData.map_by_id(opp_pref)["name"], BattleData.map_by_id(map_id)["name"]]
	var opponents: Array = []
	var ally_list: Array = []
	match mode:
		"solo":
			opponents.append(_make_fighter(rank, "enemy"))
		"tournament":
			for i in range(int(info["rounds"])):
				opponents.append(_make_fighter(rank, "enemy"))
		"clan_war":
			var picked := 0
			for name in allies:
				if picked >= 4:
					break
				for m in eligible_clan_members(rank):
					if m["name"] == name:
						ally_list.append({"name": m["name"], "class": m["class"], "rank": rank, "team": "ally", "weapon": BattleData.class_info(m["class"])["weapon"]})
						picked += 1
			for i in range(5):
				opponents.append(_make_fighter(rank, "enemy"))
		_:
			push_warning("Battle: unknown mode %s" % mode)
			return {}
	var built := {
		"mode": mode, "mode_name": info["name"], "rank": rank, "map": map_id, "map_name": BattleData.map_by_id(map_id)["name"],
		"map_rule": map_rule, "player_pref": preferred_map, "opponent_pref": opp_pref,
		"opponents": opponents, "allies": ally_list, "clan": BattleData.CLAN["name"], "rival": BattleData.CLAN["rival"],
		"message": BattleData.MATCH_READY_MESSAGE,
	}
	if dry_run:
		return built
	pending = built
	match_ready.emit(pending)
	return pending


func _make_fighter(rank: String, team: String) -> Dictionary:
	var cls: Dictionary = BattleData.CLASSES[_rng.randi_range(0, BattleData.CLASSES.size() - 1)]
	return {"name": BattleData.OPPONENT_NAMES[_rng.randi_range(0, BattleData.OPPONENT_NAMES.size() - 1)],
		"class": cls["name"], "weapon": cls["weapon"], "rank": rank, "team": team}


func clear() -> void:
	pending = {}
	match_cleared.emit()


## Called by the Spire match controller when the match ends. stats: kills, rounds_won, score...
func finish(won: bool, stats: Dictionary = {}) -> Dictionary:
	var mode: String = pending.get("mode", "solo")
	var info := mode_info(mode)
	var renown: int = int(info["win_renown"]) if won else int(info["loss_renown"])
	var points: int = int(info["win_points"]) if won else int(info["loss_points"])
	if mode == "tournament":
		renown += int(info["round_renown"]) * int(stats.get("rounds_won", 0))
		points += int(info["round_points"]) * int(stats.get("rounds_won", 0))
	RankManager.add_renown(renown)
	GameState.add_points(points)
	last_result = {"mode": mode, "mode_name": info["name"], "won": won, "renown": renown, "points": points,
		"map_name": pending.get("map_name", ""), "stats": stats}
	history.append(last_result)
	match_finished.emit(last_result)
	pending = {}
	return last_result
