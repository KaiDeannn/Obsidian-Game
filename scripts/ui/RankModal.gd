extends CanvasLayer
## RankModal (autoload scene, CanvasLayer 100). Listens to RankManager.rank_advanced and
## shows "Congratulations — Advanced to Rank C" in any scene, pausing the game until
## the player continues. Restores the previous mouse mode afterwards.

var _root: Control
var _panel: PanelContainer
var _title: Label
var _body: Label
var _badge: Label
var _badge_panel: PanelContainer
var _prev_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _queue: Array[String] = []
var _showing := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	RankManager.rank_advanced.connect(_on_rank_advanced)


func _build() -> void:
	_root = Control.new()
	_root.visible = false
	add_child(_root)
	UIKit.full_rect(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	_root.add_child(dim)
	UIKit.full_rect(dim)

	var centre := CenterContainer.new()
	_root.add_child(centre)
	UIKit.full_rect(centre)
	_panel = UIKit.panel(UIKit.PANEL_BG_SOLID, 18, UIKit.ACCENT, 28)
	_panel.custom_minimum_size = Vector2(560, 0)
	centre.add_child(_panel)
	var v := UIKit.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(v)

	var badge_centre := CenterContainer.new()
	_badge_panel = UIKit.panel(Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, 0.18), 60, UIKit.ACCENT, 0)
	_badge_panel.custom_minimum_size = Vector2(120, 120)
	_badge = UIKit.label("C", 64, UIKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_panel.add_child(_badge)
	badge_centre.add_child(_badge_panel)
	v.add_child(badge_centre)

	v.add_child(UIKit.label("RANK ADVANCEMENT", 12, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_title = UIKit.label("Congratulations — Advanced to Rank C", 26, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_title)
	_body = UIKit.wrapped("", 14, UIKit.TEXT_DIM)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_body)
	var btn := UIKit.button("Continue", UIKit.ACCENT, 16, 44)
	btn.pressed.connect(_dismiss)
	v.add_child(btn)


func _on_rank_advanced(new_rank: String, _old_rank: String) -> void:
	_queue.append(new_rank)
	if not _showing:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		return
	var rank: String = _queue.pop_front()
	_showing = true
	var color := RankManager.rank_color(rank)
	_badge.text = rank
	_badge.add_theme_color_override("font_color", color)
	_badge_panel.add_theme_stylebox_override("panel", UIKit.panel_style(Color(color.r, color.g, color.b, 0.18), 60, color, 2, 0))
	_panel.add_theme_stylebox_override("panel", UIKit.panel_style(UIKit.PANEL_BG_SOLID, 18, color, 2, 28))
	_title.text = "Congratulations — Advanced to Rank %s" % rank
	var extra := ""
	if rank == "C":
		extra = "\nMythic and Legendary gear in the Spire Armory now opens its purchase options."
	_body.text = "Your Renown reached %s. Store tiers and contracts gated behind Rank %s are now available.%s" % [UIKit.fmt_int(RankManager.renown), rank, extra]

	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_root.visible = true
	_root.modulate.a = 0.0
	_panel.scale = Vector2(0.85, 0.85)
	_panel.pivot_offset = _panel.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_root, "modulate:a", 1.0, 0.25)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _dismiss() -> void:
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func() -> void:
		_root.visible = false
		get_tree().paused = false
		Input.mouse_mode = _prev_mouse_mode
		_showing = false
		_show_next())


func _unhandled_input(event: InputEvent) -> void:
	if _showing and (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")):
		_dismiss()
