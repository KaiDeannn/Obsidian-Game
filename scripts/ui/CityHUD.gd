extends CanvasLayer
class_name CityHUD
## City heads-up display: mini-map + speedometer (top-left), wallet/rank strip (top-right),
## objective banner (top-centre), interaction prompt (bottom-centre), controls hint,
## phone button (bottom-right) and toast notifications.

signal phone_pressed

var minimap: CityMiniMap
var _root: Control
var _credits: Label
var _renown: Label
var _rank: Label
var _rank_tag: PanelContainer
var _objective_panel: PanelContainer
var _objective_label: Label
var _objective_stage: Label
var _prompt_panel: PanelContainer
var _prompt: Label
var _toasts: VBoxContainer


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	UIKit.full_rect(_root)

	# Mini-map + speedometer.
	minimap = CityMiniMap.new()
	minimap.position = Vector2(18, 18)
	_root.add_child(minimap)

	# Wallet / rank strip.
	var strip := UIKit.panel(UIKit.PANEL_BG, 12, Color(1, 1, 1, 0.1), 12)
	strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	strip.position = Vector2(-18, 18)
	strip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_root.add_child(strip)
	var row := UIKit.hbox(18)
	strip.add_child(row)
	_rank_tag = UIKit.tag("RANK D", UIKit.TEXT_DIM, 14)
	_rank = _rank_tag.get_child(0)
	row.add_child(_rank_tag)
	row.add_child(_stat_block("CREDITS", UIKit.fmt_int(GameState.credits), UIKit.GOLD, "_credits"))
	row.add_child(_stat_block("RENOWN", UIKit.fmt_int(RankManager.renown), UIKit.ACCENT2, "_renown"))
	strip.anchor_left = 1.0
	strip.anchor_right = 1.0
	strip.offset_right = -18
	strip.offset_left = -18 - 360
	strip.offset_top = 18
	strip.offset_bottom = 18 + 64

	# Objective banner.
	_objective_panel = UIKit.panel(UIKit.PANEL_BG, 12, Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, 0.45), 12)
	_root.add_child(_objective_panel)
	_objective_panel.anchor_left = 0.5
	_objective_panel.anchor_right = 0.5
	_objective_panel.offset_left = -260
	_objective_panel.offset_right = 260
	_objective_panel.offset_top = 18
	_objective_panel.offset_bottom = 78
	var ov := UIKit.vbox(2)
	_objective_panel.add_child(ov)
	_objective_stage = UIKit.label("OBJECTIVE 1/2", 11, UIKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_objective_label = UIKit.label("", 16, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	ov.add_child(_objective_stage)
	ov.add_child(_objective_label)
	_objective_panel.visible = false

	# Toasts.
	_toasts = UIKit.vbox(6)
	_root.add_child(_toasts)
	_toasts.anchor_left = 0.5
	_toasts.anchor_right = 0.5
	_toasts.offset_left = -240
	_toasts.offset_right = 240
	_toasts.offset_top = 92
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN

	# Prompt.
	_prompt_panel = UIKit.panel(UIKit.PANEL_BG, 10, Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, 0.6), 12)
	_root.add_child(_prompt_panel)
	_prompt_panel.anchor_left = 0.5
	_prompt_panel.anchor_right = 0.5
	_prompt_panel.anchor_top = 1.0
	_prompt_panel.anchor_bottom = 1.0
	_prompt_panel.offset_left = -300
	_prompt_panel.offset_right = 300
	_prompt_panel.offset_top = -120
	_prompt_panel.offset_bottom = -72
	_prompt = UIKit.label("", 17, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt_panel.add_child(_prompt)
	_prompt_panel.visible = false

	# Controls hint.
	var hint := UIKit.label("WASD Move   Shift Sprint   Space Jump   E Interact   P Phone   Esc Mouse", 12, UIKit.TEXT_DIM)
	_root.add_child(hint)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 18
	hint.offset_top = -34
	hint.offset_bottom = -14
	hint.offset_right = 700

	# Phone button.
	var phone_btn := UIKit.button("PHONE  [P]", UIKit.ACCENT2, 16, 46)
	phone_btn.pressed.connect(func() -> void: phone_pressed.emit())
	_root.add_child(phone_btn)
	phone_btn.anchor_left = 1.0
	phone_btn.anchor_right = 1.0
	phone_btn.anchor_top = 1.0
	phone_btn.anchor_bottom = 1.0
	phone_btn.offset_left = -170
	phone_btn.offset_right = -18
	phone_btn.offset_top = -64
	phone_btn.offset_bottom = -18

	GameState.credits_changed.connect(func(v: int) -> void: _credits.text = UIKit.fmt_int(v))
	RankManager.renown_changed.connect(func(v: int, _g: int) -> void: _renown.text = UIKit.fmt_int(v))
	RankManager.rank_advanced.connect(func(_n: String, _o: String) -> void: _refresh_rank())
	_refresh_rank()


func _stat_block(title: String, value: String, color: Color, store_as: String) -> VBoxContainer:
	var v := UIKit.vbox(0)
	v.add_child(UIKit.label(title, 10, UIKit.TEXT_DIM))
	var val := UIKit.label(value, 20, color)
	v.add_child(val)
	set(store_as, val)
	return v


func _refresh_rank() -> void:
	var letter := RankManager.rank_letter()
	var color := RankManager.rank_color(letter)
	_rank.text = "RANK %s" % letter
	_rank.add_theme_color_override("font_color", color)
	_rank_tag.add_theme_stylebox_override("panel", UIKit.panel_style(Color(color.r, color.g, color.b, 0.18), 6, Color(color.r, color.g, color.b, 0.7), 1, 6))


func set_prompt(text: String) -> void:
	_prompt.text = text
	_prompt_panel.visible = text != ""


func set_objective(label: String, stage: int, total: int) -> void:
	_objective_panel.visible = true
	_objective_stage.text = "OBJECTIVE %d / %d" % [stage, total]
	_objective_label.text = label


func clear_objective() -> void:
	_objective_panel.visible = false


func toast(text: String, color: Color = UIKit.TEXT) -> void:
	var p := UIKit.panel(UIKit.PANEL_BG, 8, Color(color.r, color.g, color.b, 0.5), 8)
	var l := UIKit.label(text, 14, color, HORIZONTAL_ALIGNMENT_CENTER)
	p.add_child(l)
	p.modulate.a = 0.0
	_toasts.add_child(p)
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(3.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)
