extends CanvasLayer
class_name SpireHUD
## Battlefield HUD: class selection overlay, crosshair + sniper scope overlay, health/ammo,
## match stats (Points, Renown, Rank progress), tactical mini-map (top-right), hit markers,
## reward pop-ups, pause menu and the Armory (StoreUI).

signal class_chosen(combat_class: String)
signal overlay_changed(open: bool)
signal return_to_city
signal change_class_requested

var minimap: TacticalMiniMap
var store: StoreUI

var _root: Control
var _class_select: Control
var _pause: Control
var _crosshair: Control
var _scope: Control
var _hitmarker: Control
var _hitmarker_alpha := 0.0
var _health_bar: ProgressBar
var _health_label: Label
var _ammo_label: Label
var _class_label: Label
var _state_label: Label
var _points_label: Label
var _renown_label: Label
var _rank_label: Label
var _rank_progress: ProgressBar
var _rank_next: Label
var _popups: VBoxContainer
var _toasts: VBoxContainer
var _player: SpirePlayer
var _aiming := false


class Crosshair extends Control:
	var aiming := false
	var spread := 10.0
	func _draw() -> void:
		var c := size * 0.5
		if aiming:
			return
		var col := Color(1, 1, 1, 0.9)
		draw_circle(c, 2.0, col)
		for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(c + d * spread, c + d * (spread + 9.0), col, 2.0, true)


class Scope extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		# Black outside the lens.
		var pts := PackedVector2Array()
		var steps := 96
		for i in range(steps + 1):
			var a := TAU * i / steps
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		# Four big quads around the circle approximated with a thick ring + corner rects.
		draw_rect(Rect2(0, 0, size.x, c.y - r), Color.BLACK)
		draw_rect(Rect2(0, c.y + r, size.x, size.y - (c.y + r)), Color.BLACK)
		draw_rect(Rect2(0, c.y - r, c.x - r, 2 * r), Color.BLACK)
		draw_rect(Rect2(c.x + r, c.y - r, size.x - (c.x + r), 2 * r), Color.BLACK)
		draw_arc(c, r + 40, 0, TAU, 128, Color.BLACK, 84.0)
		draw_arc(c, r, 0, TAU, 128, Color(0.1, 0.1, 0.12), 6.0, true)
		draw_arc(c, r - 4, 0, TAU, 128, Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, 0.5), 2.0, true)
		# Reticle.
		var rc := Color(0.1, 0.1, 0.1, 0.95)
		draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), rc, 1.5, true)
		draw_line(c + Vector2(0, -r), c + Vector2(0, r), rc, 1.5, true)
		draw_line(c + Vector2(-r, 0), c + Vector2(-r * 0.25, 0), rc, 5.0)
		draw_line(c + Vector2(r * 0.25, 0), c + Vector2(r, 0), rc, 5.0)
		draw_line(c + Vector2(0, r * 0.25), c + Vector2(0, r), rc, 5.0)
		# Mil-dots below centre for holdover.
		for k in range(1, 5):
			var y := k * 26.0
			draw_circle(c + Vector2(0, y), 2.5, rc)
			draw_line(c + Vector2(-8, y), c + Vector2(8, y), rc, 1.0)
		draw_circle(c, 2.0, Color(1.0, 0.25, 0.3))
		draw_string(ThemeDB.fallback_font, c + Vector2(r * 0.55, -r * 0.6), "6.0x   ZERO 60m", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, 0.8))


class HitMarker extends Control:
	var alpha := 0.0
	var headshot := false
	func _draw() -> void:
		if alpha <= 0.0:
			return
		var c := size * 0.5
		var col := Color(1.0, 0.8, 0.3, alpha) if headshot else Color(1, 1, 1, alpha)
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(c + d * 8.0, c + d * 18.0, col, 2.5, true)


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	UIKit.full_rect(_root)
	_build_combat_hud()
	_build_class_select()
	_build_pause()
	store = StoreUI.new()
	store.closed.connect(func() -> void: overlay_changed.emit(false))
	add_child(store)
	GameState.points_changed.connect(func(v: int) -> void: _points_label.text = UIKit.fmt_int(v))
	RankManager.renown_changed.connect(func(_v: int, _g: int) -> void: _refresh_rank())
	RankManager.rank_advanced.connect(func(_n: String, _o: String) -> void: _refresh_rank())
	_refresh_rank()
	_points_label.text = UIKit.fmt_int(GameState.points)


func _process(delta: float) -> void:
	if _hitmarker_alpha > 0.0:
		_hitmarker_alpha = maxf(0.0, _hitmarker_alpha - delta * 3.0)
		(_hitmarker as HitMarker).alpha = _hitmarker_alpha
		_hitmarker.queue_redraw()
	if _crosshair.visible:
		var ch := _crosshair as Crosshair
		var moving := is_instance_valid(_player) and Vector2(_player.velocity.x, _player.velocity.z).length() > 1.0
		ch.spread = lerpf(ch.spread, 18.0 if moving else 10.0, 8.0 * delta)
		ch.queue_redraw()


# ------------------------------------------------------------------ combat HUD
func _build_combat_hud() -> void:
	_crosshair = Crosshair.new()
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_crosshair)
	UIKit.full_rect(_crosshair)
	_scope = Scope.new()
	_scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope.visible = false
	_root.add_child(_scope)
	UIKit.full_rect(_scope)
	_hitmarker = HitMarker.new()
	_hitmarker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hitmarker)
	UIKit.full_rect(_hitmarker)

	# Top-left: class, health, ammo.
	var status := UIKit.panel(UIKit.PANEL_BG, 12, Color(1, 1, 1, 0.1), 12)
	status.position = Vector2(18, 18)
	status.custom_minimum_size = Vector2(300, 0)
	_root.add_child(status)
	var sv := UIKit.vbox(6)
	status.add_child(sv)
	var top := UIKit.hbox(8)
	_class_label = UIKit.label("SWORDSMAN", 14, UIKit.ACCENT)
	top.add_child(_class_label)
	top.add_child(UIKit.spacer())
	_state_label = UIKit.label("", 12, UIKit.TEXT_DIM)
	top.add_child(_state_label)
	sv.add_child(top)
	_health_bar = UIKit.progress(1.0, UIKit.GREEN, 14)
	sv.add_child(_health_bar)
	var hrow := UIKit.hbox(8)
	_health_label = UIKit.label("100 / 100", 13, UIKit.TEXT)
	hrow.add_child(_health_label)
	hrow.add_child(UIKit.spacer())
	_ammo_label = UIKit.label("", 15, UIKit.AMBER)
	hrow.add_child(_ammo_label)
	sv.add_child(hrow)

	# Top-centre: match stats.
	var stats := UIKit.panel(UIKit.PANEL_BG, 12, Color(UIKit.ACCENT2.r, UIKit.ACCENT2.g, UIKit.ACCENT2.b, 0.4), 12)
	_root.add_child(stats)
	stats.anchor_left = 0.5
	stats.anchor_right = 0.5
	stats.offset_left = -230
	stats.offset_right = 230
	stats.offset_top = 18
	stats.offset_bottom = 90
	var srow := UIKit.hbox(22)
	stats.add_child(srow)
	srow.add_child(_stat("POINTS", "_points_label", UIKit.ACCENT))
	srow.add_child(_stat("RENOWN", "_renown_label", UIKit.ACCENT2))
	var rank_col := UIKit.vbox(2)
	rank_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_col.add_child(UIKit.label("RANK", 10, UIKit.TEXT_DIM))
	_rank_label = UIKit.label("D", 20, UIKit.TEXT)
	rank_col.add_child(_rank_label)
	_rank_progress = UIKit.progress(0.0, UIKit.ACCENT, 6)
	rank_col.add_child(_rank_progress)
	_rank_next = UIKit.label("", 10, UIKit.TEXT_DIM)
	rank_col.add_child(_rank_next)
	srow.add_child(rank_col)

	# Top-right: tactical mini-map.
	minimap = TacticalMiniMap.new()
	_root.add_child(minimap)
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.offset_left = -228
	minimap.offset_right = -18
	minimap.offset_top = 18
	minimap.offset_bottom = 228
	var map_hint := UIKit.label("TACTICAL  -  LOS markers", 10, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_root.add_child(map_hint)
	map_hint.anchor_left = 1.0
	map_hint.anchor_right = 1.0
	map_hint.offset_left = -228
	map_hint.offset_right = -18
	map_hint.offset_top = 232
	map_hint.offset_bottom = 248

	# Reward popups (centre, above crosshair).
	_popups = UIKit.vbox(4)
	_popups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_popups)
	_popups.anchor_left = 0.5
	_popups.anchor_right = 0.5
	_popups.anchor_top = 0.5
	_popups.anchor_bottom = 0.5
	_popups.offset_left = -200
	_popups.offset_right = 200
	_popups.offset_top = -170
	_popups.offset_bottom = -60
	_popups.alignment = BoxContainer.ALIGNMENT_END
	_toasts = UIKit.vbox(6)
	_root.add_child(_toasts)
	_toasts.anchor_left = 0.5
	_toasts.anchor_right = 0.5
	_toasts.offset_left = -260
	_toasts.offset_right = 260
	_toasts.offset_top = 100

	# Bottom hints.
	var hint := UIKit.label("WASD Move   Shift Sprint   Space Jump   LMB Attack / Fire   RMB Block / Aim   R Reload   B Armory   Esc Menu", 12, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_root.add_child(hint)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.anchor_right = 1.0
	hint.offset_top = -34
	hint.offset_bottom = -14


func _stat(title: String, store_as: String, color: Color) -> VBoxContainer:
	var v := UIKit.vbox(0)
	v.add_child(UIKit.label(title, 10, UIKit.TEXT_DIM))
	var val := UIKit.label("0", 22, color)
	v.add_child(val)
	set(store_as, val)
	return v


func _refresh_rank() -> void:
	var letter := RankManager.rank_letter()
	var color := RankManager.rank_color(letter)
	_rank_label.text = letter
	_rank_label.add_theme_color_override("font_color", color)
	_renown_label.text = UIKit.fmt_int(RankManager.renown)
	_rank_progress.value = RankManager.progress_ratio()
	var nxt := RankManager.next_threshold()
	_rank_next.text = ("%s / %s to Rank %s" % [UIKit.fmt_int(RankManager.renown), UIKit.fmt_int(nxt), RankManager.RANKS[RankManager.rank_index + 1]]) if nxt > 0 else "MAX RANK"


# ------------------------------------------------------------------ player binding
func bind_player(p: SpirePlayer) -> void:
	_player = p
	minimap.bind_player(p)
	p.health_changed.connect(_on_health)
	p.ammo_changed.connect(_on_ammo)
	p.aim_changed.connect(_on_aim)
	p.hit_landed.connect(_on_hit)
	p.block_state.connect(_on_block)
	p.reloading.connect(func(d: float) -> void: _state_label.text = "RELOADING"; get_tree().create_timer(d).timeout.connect(func() -> void: if _state_label.text == "RELOADING": _state_label.text = ""))
	var is_sword := p.combat_class == GameState.CLASS_SWORDSMAN
	_class_label.text = p.combat_class.to_upper()
	_class_label.add_theme_color_override("font_color", UIKit.ACCENT2 if is_sword else UIKit.ACCENT)
	_ammo_label.visible = not is_sword
	_state_label.text = "MELEE  -  RMB to block" if is_sword else "RMB to aim"
	_on_health(p.hp, p.max_hp)
	_on_ammo(p.ammo, p.reserve)


func _on_health(hp: float, max_hp: float) -> void:
	var ratio := hp / max_hp
	_health_bar.value = ratio
	_health_label.text = "%d / %d" % [int(hp), int(max_hp)]
	var col := UIKit.GREEN if ratio > 0.5 else (UIKit.AMBER if ratio > 0.25 else UIKit.RED)
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(7)
	_health_bar.add_theme_stylebox_override("fill", fill)


func _on_ammo(ammo: int, reserve: int) -> void:
	_ammo_label.text = "%d / %d" % [ammo, reserve]


func _on_aim(aiming: bool) -> void:
	_aiming = aiming
	_scope.visible = aiming
	(_crosshair as Crosshair).aiming = aiming
	_crosshair.queue_redraw()
	_state_label.text = "AIMING  -  6.0x" if aiming else "RMB to aim"


func _on_hit(_target: Node3D, damage: float, headshot: bool) -> void:
	_hitmarker_alpha = 1.0
	(_hitmarker as HitMarker).headshot = headshot
	_popup("%s%d" % ["HEADSHOT  " if headshot else "", int(damage)], UIKit.GOLD if headshot else Color.WHITE, 15)


func _on_block(blocking: bool, parried: bool) -> void:
	if parried:
		_popup("PARRY!", UIKit.ACCENT, 22)
		_state_label.text = "PARRIED"
	elif blocking:
		_state_label.text = "BLOCKING"
	else:
		_state_label.text = "MELEE  -  RMB to block"


func reward_popup(text: String) -> void:
	_popup(text, UIKit.GREEN, 18)


func _popup(text: String, color: Color, size: int) -> void:
	var l := UIKit.label(text, size, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	_popups.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func toast(text: String, color: Color = UIKit.TEXT) -> void:
	var p := UIKit.panel(UIKit.PANEL_BG, 8, Color(color.r, color.g, color.b, 0.5), 8)
	p.add_child(UIKit.label(text, 14, color, HORIZONTAL_ALIGNMENT_CENTER))
	p.modulate.a = 0.0
	_toasts.add_child(p)
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(3.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


# ------------------------------------------------------------------ class select
func _build_class_select() -> void:
	_class_select = Control.new()
	_class_select.visible = false
	add_child(_class_select)
	UIKit.full_rect(_class_select)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.015, 0.84)
	_class_select.add_child(dim)
	UIKit.full_rect(dim)
	var centre := CenterContainer.new()
	_class_select.add_child(centre)
	UIKit.full_rect(centre)
	var v := UIKit.vbox(18)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(v)
	v.add_child(UIKit.label("THE SPIRE RUINS  -  CENTRAL PLAZA", 13, UIKit.ACCENT2, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("Select your class", 34, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var row := UIKit.hbox(24)
	v.add_child(row)
	row.add_child(_class_card(GameState.CLASS_SWORDSMAN, "1", UIKit.ACCENT2,
		"Obsidian blade and kinetic shield.",
		["LMB  -  Sweeping strike (38 dmg)", "RMB  -  Block (88% reduction)", "Block timing  -  Parry window 0.3s staggers hunters", "High mobility, lunge on attack"]))
	row.add_child(_class_card(GameState.CLASS_SNIPER, "2", UIKit.ACCENT,
		"Long rifle with 6x optic.",
		["RMB  -  Aim: first-person scope, 6.0x", "LMB  -  Fire (70 dmg, x2 headshot)", "Bullet adjustment  -  drop vs 60m zero + spread", "5-round magazine, R to reload"]))
	v.add_child(UIKit.label("Press 1 or 2, or click a class to deploy", 13, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var back := UIKit.button("Return to Nova Aetheris", UIKit.TEXT_DIM, 13, 34)
	back.pressed.connect(func() -> void: return_to_city.emit())
	v.add_child(back)


func _class_card(cls: String, key: String, color: Color, blurb: String, lines: Array) -> Control:
	var p := UIKit.panel(UIKit.CARD_BG, 16, Color(color.r, color.g, color.b, 0.6), 20)
	p.custom_minimum_size = Vector2(360, 0)
	var v := UIKit.vbox(10)
	p.add_child(v)
	var head := UIKit.hbox(10)
	head.add_child(UIKit.tag("[%s]" % key, color, 14))
	head.add_child(UIKit.label(cls.to_upper(), 24, color))
	v.add_child(head)
	v.add_child(UIKit.wrapped(blurb, 14, UIKit.TEXT))
	v.add_child(UIKit.separator())
	for line in lines:
		v.add_child(UIKit.wrapped("-  %s" % line, 13))
	var btn := UIKit.button("Deploy as %s" % cls, color, 16, 44)
	btn.pressed.connect(func() -> void: class_chosen.emit(cls))
	v.add_child(btn)
	return p


func show_class_select() -> void:
	_class_select.visible = true
	_pause.visible = false
	_crosshair.visible = false
	overlay_changed.emit(true)


func hide_overlays() -> void:
	_class_select.visible = false
	_pause.visible = false
	_crosshair.visible = true
	if store.visible:
		store.close()
	overlay_changed.emit(false)


func is_overlay_open() -> bool:
	return _class_select.visible or _pause.visible or store.visible


# ------------------------------------------------------------------ pause
func _build_pause() -> void:
	_pause = Control.new()
	_pause.visible = false
	add_child(_pause)
	UIKit.full_rect(_pause)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	_pause.add_child(dim)
	UIKit.full_rect(dim)
	var centre := CenterContainer.new()
	_pause.add_child(centre)
	UIKit.full_rect(centre)
	var p := UIKit.panel(UIKit.PANEL_BG_SOLID, 16, UIKit.ACCENT, 24)
	p.custom_minimum_size = Vector2(380, 0)
	centre.add_child(p)
	var v := UIKit.vbox(10)
	p.add_child(v)
	v.add_child(UIKit.label("PAUSED", 26, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var resume := UIKit.button("Resume", UIKit.ACCENT, 15, 40)
	resume.pressed.connect(hide_overlays)
	v.add_child(resume)
	var armory := UIKit.button("Open Armory", UIKit.ACCENT2, 15, 40)
	armory.pressed.connect(func() -> void:
		_pause.visible = false
		store.open())
	v.add_child(armory)
	var cls := UIKit.button("Change class", UIKit.TEXT_DIM, 15, 40)
	cls.pressed.connect(func() -> void: change_class_requested.emit())
	v.add_child(cls)
	var leave := UIKit.button("Return to Nova Aetheris", UIKit.AMBER, 15, 40)
	leave.pressed.connect(func() -> void: return_to_city.emit())
	v.add_child(leave)


func toggle_pause() -> void:
	if _pause.visible:
		hide_overlays()
	else:
		_pause.visible = true
		overlay_changed.emit(true)


func toggle_store() -> void:
	if store.visible:
		store.close()
		if not _pause.visible and not _class_select.visible:
			overlay_changed.emit(false)
	else:
		_pause.visible = false
		store.open()
		overlay_changed.emit(true)
