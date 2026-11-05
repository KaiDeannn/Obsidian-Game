extends Node3D
## Match controller for The Spire Ruins. Two ways in:
##  - Training ground (no pending match): class select -> spawn, dummies and hunters pay
##    Points + Renown per takedown and respawn, as before.
##  - Battle (Battle.has_pending()): the training enemies are cleared and the match from
##    BattleManager runs here. Solo = one opponent, death restarts the attempt from the
##    beginning. Tournament = three rounds, elimination means spectating until the result.
##    Clan War = five a side with respawns, first team to the kill target (or the higher
##    score at the time limit) wins. Results pay out through Battle.finish().
## RankManager fires the Rank C modal automatically.
## Hierarchy: see README (SpireRuins.tscn).

const CITY_SCENE := "res://scenes/city/NovaAetheris.tscn"
const PLAYER_SCENE := preload("res://scenes/spire/SpirePlayer.tscn")
const FIGHTER_SCENE := preload("res://scenes/spire/BattleFighter.tscn")

@onready var hud: SpireHUD = $SpireHUD
@onready var spawn: Marker3D = $PlayerSpawn
@onready var enemies: Node3D = $Enemies
@onready var sun: DirectionalLight3D = $SunLight

var player: SpirePlayer
var kills := 0
var match_points := 0
var match_renown := 0
var _leaving := false

# ---- battle state
var fight: Dictionary = {}
var fighters: Array = []
var match_active := false
var match_time := 0.0
var round_index := 0
var rounds_won := 0
var player_kills := 0
var attempts := 1
var team_score := {"ally": 0, "enemy": 0}
var _spectating := false


func _ready() -> void:
	sun.rotation_degrees = Vector3(-38, 28, 0)       # low sun from behind the spawn
	hud.class_chosen.connect(_deploy)
	hud.overlay_changed.connect(_on_overlay_changed)
	hud.return_to_city.connect(_return_to_city)
	hud.change_class_requested.connect(func() -> void: hud.show_class_select())
	hud.rematch_requested.connect(_rematch)
	if Battle.has_pending():
		fight = Battle.pending.duplicate(true)
		for enemy in enemies.get_children():
			enemy.queue_free()
		hud.set_match_banner("%s  -  %s  -  Rank %s" % [fight["mode_name"].to_upper(), fight["map_name"].to_upper(), fight["rank"]])
	else:
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if enemy is TrainingDummy:
				enemy.defeated.connect(_on_enemy_defeated)
	hud.show_class_select()


func is_battle() -> bool:
	return not fight.is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or _spectating or Cinematic.is_playing:
		return
	if hud._class_select.visible:
		if event.is_action_pressed("class_1"):
			_deploy(GameState.CLASS_SWORDSMAN)
		elif event.is_action_pressed("class_2"):
			_deploy(GameState.CLASS_SNIPER)
		elif event.is_action_pressed("class_3"):
			_deploy(GameState.CLASS_ENGINEER)
		return
	if hud.results_open():
		return
	if event.is_action_pressed("ui_cancel"):
		if hud.store.visible:
			hud.toggle_store()
		else:
			hud.toggle_pause()
	elif event.is_action_pressed("store"):
		hud.toggle_store()
	elif event.is_action_pressed("weapon_next") and is_instance_valid(player) and not hud.is_overlay_open() and player.combat_class == GameState.CLASS_ENGINEER:
		player.cycle_weapon(1)
		var w := player.weapon
		hud.toast("%s  -  %s" % [w["name"], w["type"]], UIKit.rarity_color(w["rarity"]))
	elif event is InputEventMouseButton and event.pressed and not hud.is_overlay_open() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if not match_active:
		return
	match_time += delta
	hud.update_match(_match_line())
	if fight["mode"] == "clan_war" and match_time >= float(Battle.mode_info("clan_war")["time_limit"]):
		_end_match(team_score["ally"] > team_score["enemy"])


func _match_line() -> String:
	match fight.get("mode", ""):
		"solo":
			var opp: BattleFighter = fighters[0] if not fighters.is_empty() else null
			var opp_hp := int(opp.hp) if is_instance_valid(opp) else 0
			return "SOLO  -  vs %s (%s)   their HP %d   attempt %d   %s" % [fight["opponents"][0]["name"], fight["opponents"][0]["class"], maxi(opp_hp, 0), attempts, _fmt_time(match_time)]
		"tournament":
			return "TOURNAMENT  -  round %d / %d   won %d   %s" % [round_index + 1, int(Battle.mode_info("tournament")["rounds"]), rounds_won, _fmt_time(match_time)]
		"clan_war":
			var limit: float = float(Battle.mode_info("clan_war")["time_limit"])
			return "CLAN WAR  -  %s %d : %d %s   first to %d   %s left" % [fight["clan"], team_score["ally"], team_score["enemy"], fight["rival"], int(Battle.mode_info("clan_war")["kill_target"]), _fmt_time(maxf(0.0, limit - match_time))]
	return ""


static func _fmt_time(t: float) -> String:
	var s := int(t)
	@warning_ignore("integer_division")
	return "%d:%02d" % [s / 60, s % 60]


# ------------------------------------------------------------------ deploy
func _deploy(combat_class: String) -> void:
	GameState.set_class(combat_class)
	if is_instance_valid(player):
		player.queue_free()
	player = PLAYER_SCENE.instantiate()
	player.setup(combat_class)
	add_child(player)
	player.global_position = spawn.global_position
	player.rotation.y = spawn.rotation.y
	player.died.connect(_on_player_died)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is TrainingDummy and not (enemy is BattleFighter):
			enemy.player = player
	hud.bind_player(player)
	hud.hide_overlays()
	if is_battle():
		if not match_active:
			_start_match()
		return
	hud.toast("Deployed as %s  -  defeat targets to earn Points and Renown" % combat_class, UIKit.ACCENT)
	if combat_class == GameState.CLASS_SNIPER:
		hud.toast("Vantage platforms in the NE and SW corners give clean sightlines", UIKit.TEXT_DIM)
	elif combat_class == GameState.CLASS_ENGINEER:
		hud.toast("LMB fires, throws or places your weapon  -  Q switches between all ten", UIKit.TEXT_DIM)
	else:
		hud.toast("Block just as a Hunter strikes to parry and stagger it", UIKit.TEXT_DIM)


func _on_overlay_changed(open: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
	if is_instance_valid(player):
		player.input_enabled = not open
		if open and player.is_aiming:
			player.set_aiming(false)
		if open and player.is_blocking:
			player.set_blocking(false)


# ------------------------------------------------------------------ training ground
func _on_enemy_defeated(dummy: TrainingDummy) -> void:
	kills += 1
	GameState.kills += 1
	match_points += dummy.points_reward
	match_renown += dummy.renown_reward
	GameState.add_points(dummy.points_reward)
	RankManager.add_renown(dummy.renown_reward)
	hud.reward_popup("+%d PTS   +%d RENOWN" % [dummy.points_reward, dummy.renown_reward])
	if kills % 5 == 0:
		hud.toast("Takedown streak: %d   Match total: %d pts / %d renown" % [kills, match_points, match_renown], UIKit.GREEN)


# ------------------------------------------------------------------ battle: start
func _start_match() -> void:
	match_time = 0.0
	round_index = 0
	rounds_won = 0
	player_kills = 0
	attempts = 1
	team_score = {"ally": 0, "enemy": 0}
	_clear_fighters()
	player.input_enabled = false
	# arena fly-in, then the countdown
	await Cinematic.play_named("battle_intro", {"resolve": _resolve_cine_point, "skippable": true, "fade_in": false})
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	match fight["mode"]:
		"solo":
			_spawn_enemy(fight["opponents"][0], Vector3(0, 0.6, -44))
		"tournament":
			_spawn_enemy(fight["opponents"][0], Vector3(0, 0.6, -44))
		"clan_war":
			var i := 0
			for a in fight["allies"]:
				var f := _spawn_fighter(a, Vector3(-6.0 + i * 4.0, 0.6, 42))
				f.respawns = true
				i += 1
			var j := 0
			for e in fight["opponents"]:
				var f := _spawn_fighter(e, Vector3(-8.0 + j * 4.0, 0.6, -44))
				f.respawns = true
				j += 1
	for f in fighters:
		f.set_physics_process(false)
	await hud.countdown()
	for f in fighters:
		if is_instance_valid(f):
			f.set_physics_process(true)
	player.input_enabled = not hud.is_overlay_open()
	match_active = true
	hud.toast("%s on %s  -  %s" % [fight["mode_name"], fight["map_name"], fight["map_rule"]], UIKit.TEXT_DIM)


func _spawn_enemy(data: Dictionary, pos: Vector3) -> BattleFighter:
	return _spawn_fighter(data, pos)


func _spawn_fighter(data: Dictionary, pos: Vector3) -> BattleFighter:
	var f: BattleFighter = FIGHTER_SCENE.instantiate()
	f.setup(data)
	f.position = pos
	f.name = "Fighter_%s_%d" % [data["team"], fighters.size()]
	add_child(f)
	f.defeated.connect(_on_fighter_defeated)
	fighters.append(f)
	return f


func _clear_fighters() -> void:
	for f in fighters:
		if is_instance_valid(f):
			f.queue_free()
	fighters.clear()


func _resolve_cine_point(key: String) -> Variant:
	if not is_instance_valid(player):
		return Vector3.ZERO
	var p := player.global_position
	var back := player.global_transform.basis.z
	match key:
		"player_back":
			return {"pos": p + back * 3.6 + Vector3.UP * 2.0, "look": p + Vector3.UP * 1.3 - back * 4.0}
		"player":
			return player
	return Vector3.ZERO


# ------------------------------------------------------------------ battle: events
func _on_fighter_defeated(f: TrainingDummy) -> void:
	if not match_active or not (f is BattleFighter):
		return
	var bf := f as BattleFighter
	if bf.team == "enemy":
		team_score["ally"] += 1
		if bf.last_attacker == player:
			player_kills += 1
			GameState.add_points(bf.points_reward)
			RankManager.add_renown(bf.renown_reward)
			hud.reward_popup("+%d PTS   +%d RENOWN" % [bf.points_reward, bf.renown_reward])
		match fight["mode"]:
			"solo":
				_end_match(true)
			"tournament":
				rounds_won += 1
				if rounds_won >= int(Battle.mode_info("tournament")["rounds"]):
					_end_match(true)
				else:
					_next_round()
			"clan_war":
				if team_score["ally"] >= int(Battle.mode_info("clan_war")["kill_target"]):
					_end_match(true)
	else:
		team_score["enemy"] += 1
		if fight["mode"] == "clan_war" and team_score["enemy"] >= int(Battle.mode_info("clan_war")["kill_target"]):
			_end_match(false)


func _next_round() -> void:
	match_active = false
	round_index += 1
	hud.reward_popup("ROUND %d WON" % round_index)
	await get_tree().create_timer(2.2).timeout
	if _leaving or is_battle() == false:
		return
	player.hp = player.max_hp
	player.health_changed.emit(player.hp, player.max_hp)
	_clear_fighters()
	_spawn_enemy(fight["opponents"][round_index], Vector3(0, 0.6, -44))
	hud.big_popup("ROUND %d" % (round_index + 1), UIKit.ACCENT2)
	match_active = true


func _on_player_died() -> void:
	if not is_battle():
		hud.toast("You were downed  -  redeploying in 3s", UIKit.RED)
		await get_tree().create_timer(3.0).timeout
		if is_instance_valid(player):
			player.respawn(spawn.global_position)
		return
	if not match_active:
		return
	match fight["mode"]:
		"solo":
			match_active = false
			attempts += 1
			hud.big_popup("DOWNED  -  ATTEMPT RESTARTS", UIKit.RED)
			await get_tree().create_timer(2.4).timeout
			if _leaving or not is_battle():
				return
			player.respawn(spawn.global_position)
			for f in fighters:
				if is_instance_valid(f):
					(f as BattleFighter).revive(Vector3(0, 0.6, -44))
			match_active = true
		"tournament":
			match_active = false
			_spectating = true
			hud.big_popup("ELIMINATED  -  SPECTATING", UIKit.RED)
			await Cinematic.play(CinematicData.SEQUENCES["battle_intro"].slice(0, 1), {"skippable": false, "fade_in": false, "fade_out": true})
			_spectating = false
			_end_match(false)
		"clan_war":
			team_score["enemy"] += 1
			if team_score["enemy"] >= int(Battle.mode_info("clan_war")["kill_target"]):
				_end_match(false)
				return
			hud.toast("Downed  -  respawning in 3s", UIKit.RED)
			await get_tree().create_timer(3.0).timeout
			if is_instance_valid(player) and match_active:
				player.respawn(spawn.global_position)


func _end_match(won: bool) -> void:
	if not match_active and fight.is_empty():
		return
	match_active = false
	var stats := {"kills": player_kills, "rounds_won": rounds_won, "score": team_score.duplicate(), "time": match_time, "attempts": attempts}
	var result := Battle.finish(won, stats)
	result["announced"] = true
	for f in fighters:
		if is_instance_valid(f):
			f.set_physics_process(false)
	hud.show_results(result)


func _rematch() -> void:
	var mode: String = fight.get("mode", "solo")
	var pref: String = fight.get("player_pref", "ruins")
	var allies: Array = []
	for a in fight.get("allies", []):
		allies.append(a["name"])
	fight = Battle.setup_match(mode, pref, allies).duplicate(true)
	hud.hide_results()
	hud.set_match_banner("%s  -  %s  -  Rank %s" % [fight["mode_name"].to_upper(), fight["map_name"].to_upper(), fight["rank"]])
	if is_instance_valid(player):
		player.respawn(spawn.global_position)
	_start_match()


func _return_to_city() -> void:
	if _leaving:
		return
	_leaving = true
	if is_battle() and Battle.has_pending():
		Battle.clear()      # walked out of an unfinished match
	GameState.arrival_from_spire = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().change_scene_to_file(CITY_SCENE)
