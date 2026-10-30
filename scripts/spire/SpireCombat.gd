extends Node3D
## Match controller for The Spire Ruins. Owns class selection -> player spawn, enemy
## reward wiring (Points + Renown per takedown), respawns, pause/store overlays, and the
## return trip to Nova Aetheris. RankManager fires the Rank C modal automatically.
## Hierarchy: see README (SpireRuins.tscn).

const CITY_SCENE := "res://scenes/city/NovaAetheris.tscn"
const PLAYER_SCENE := preload("res://scenes/spire/SpirePlayer.tscn")

@onready var hud: SpireHUD = $SpireHUD
@onready var spawn: Marker3D = $PlayerSpawn
@onready var enemies: Node3D = $Enemies
@onready var sun: DirectionalLight3D = $SunLight

var player: SpirePlayer
var kills := 0
var match_points := 0
var match_renown := 0
var _leaving := false


func _ready() -> void:
	sun.rotation_degrees = Vector3(-28, -140, 0)
	hud.class_chosen.connect(_deploy)
	hud.overlay_changed.connect(_on_overlay_changed)
	hud.return_to_city.connect(_return_to_city)
	hud.change_class_requested.connect(func() -> void: hud.show_class_select())
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is TrainingDummy:
			enemy.defeated.connect(_on_enemy_defeated)
	hud.show_class_select()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if hud._class_select.visible:
		if event.is_action_pressed("class_1"):
			_deploy(GameState.CLASS_SWORDSMAN)
		elif event.is_action_pressed("class_2"):
			_deploy(GameState.CLASS_SNIPER)
		return
	if event.is_action_pressed("ui_cancel"):
		if hud.store.visible:
			hud.toggle_store()
		else:
			hud.toggle_pause()
	elif event.is_action_pressed("store"):
		hud.toggle_store()
	elif event is InputEventMouseButton and event.pressed and not hud.is_overlay_open() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
		if enemy is TrainingDummy:
			enemy.player = player
	hud.bind_player(player)
	hud.hide_overlays()
	hud.toast("Deployed as %s  -  defeat targets to earn Points and Renown" % combat_class, UIKit.ACCENT)
	if combat_class == GameState.CLASS_SNIPER:
		hud.toast("Vantage platforms in the NE and SW corners give clean sightlines", UIKit.TEXT_DIM)
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


func _on_player_died() -> void:
	hud.toast("You were downed  -  redeploying in 3s", UIKit.RED)
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(player):
		player.respawn(spawn.global_position)


func _return_to_city() -> void:
	if _leaving:
		return
	_leaving = true
	GameState.arrival_from_spire = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().change_scene_to_file(CITY_SCENE)
