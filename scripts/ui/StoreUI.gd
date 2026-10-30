extends Control
class_name StoreUI
## Spire Armory. Implements the two-step purchase rule:
##   Step 1 - Rank verification. Mythic/Legendary gear explicitly requires Rank C.
##            Below that rank the item is LOCKED and no purchase controls exist at all.
##   Step 2 - Only after the rank check passes does "Open purchase options" reveal the
##            buy buttons (Credits or Points).

signal closed

var _panel: PanelContainer
var _list: VBoxContainer
var _detail: VBoxContainer
var _rank_line: Label
var _selected_id := ""
var _step2_open := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	UIKit.full_rect(self)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	UIKit.full_rect(dim)
	var centre := CenterContainer.new()
	add_child(centre)
	UIKit.full_rect(centre)
	_panel = UIKit.panel(UIKit.PANEL_BG_SOLID, 16, UIKit.ACCENT2, 20)
	_panel.custom_minimum_size = Vector2(900, 560)
	centre.add_child(_panel)
	var v := UIKit.vbox(12)
	_panel.add_child(v)
	var head := UIKit.hbox(12)
	var title_col := UIKit.vbox(0)
	title_col.add_child(UIKit.label("SPIRE ARMORY", 24, UIKit.TEXT))
	title_col.add_child(UIKit.label("Requisitions  -  Mythic & Legendary tiers require Rank C before purchase options open", 12, UIKit.TEXT_DIM))
	head.add_child(title_col)
	head.add_child(UIKit.spacer())
	_rank_line = UIKit.label("", 14, UIKit.TEXT)
	head.add_child(_rank_line)
	var close_btn := UIKit.button("Close  [B]", UIKit.TEXT_DIM, 13, 34)
	close_btn.pressed.connect(close)
	head.add_child(close_btn)
	v.add_child(head)
	v.add_child(UIKit.separator())
	var body := UIKit.hbox(16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(430, 0)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	_list = UIKit.vbox(10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	var detail_panel := UIKit.panel(UIKit.CARD_BG, 12, Color(1, 1, 1, 0.08), 16)
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(detail_panel)
	_detail = UIKit.vbox(10)
	detail_panel.add_child(_detail)
	GameState.credits_changed.connect(func(_v: int) -> void: if visible: refresh())
	GameState.points_changed.connect(func(_v: int) -> void: if visible: refresh())
	RankManager.rank_advanced.connect(func(_n: String, _o: String) -> void: if visible: refresh())


func open() -> void:
	visible = true
	_step2_open = false
	refresh()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.18)


func close() -> void:
	visible = false
	closed.emit()


func refresh() -> void:
	var letter := RankManager.rank_letter()
	_rank_line.text = "Your Rank: %s     Credits: %s     Points: %s" % [letter, UIKit.fmt_int(GameState.credits), UIKit.fmt_int(GameState.points)]
	for c in _list.get_children():
		c.queue_free()
	for item in CityData.GEAR:
		_list.add_child(_item_card(item))
	_build_detail()


func _item_card(item: Dictionary) -> Control:
	var tier: String = item["tier"]
	var tcol := UIKit.tier_color(tier)
	var owned := GameState.owns_gear(item["id"])
	var unlocked := RankManager.meets_rank(item["required_rank"])
	var selected: bool = _selected_id == item["id"]
	var p := UIKit.panel(UIKit.CARD_BG, 12, tcol if selected else Color(tcol.r, tcol.g, tcol.b, 0.35), 12)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UIKit.vbox(6)
	p.add_child(v)
	var top := UIKit.hbox(8)
	top.add_child(UIKit.tag(tier.to_upper(), tcol, 10))
	top.add_child(UIKit.label(item["name"], 17, UIKit.TEXT))
	top.add_child(UIKit.spacer())
	if owned:
		top.add_child(UIKit.tag("OWNED", UIKit.GREEN, 10))
	elif not unlocked:
		top.add_child(UIKit.tag("LOCKED  -  REQUIRES RANK %s" % item["required_rank"], UIKit.RED, 10))
	else:
		top.add_child(UIKit.tag("RANK %s OK" % item["required_rank"], UIKit.GREEN, 10))
	v.add_child(top)
	v.add_child(UIKit.label("%s   |   %s cr  or  %s pts" % [item["class"], UIKit.fmt_int(item["price_credits"]), UIKit.fmt_int(item["price_points"])], 12, UIKit.TEXT_DIM))
	var btn := UIKit.button("Inspect", tcol, 13, 32)
	var iid: String = item["id"]
	btn.pressed.connect(func() -> void:
		_selected_id = iid
		_step2_open = false
		refresh())
	v.add_child(btn)
	return p


func _gear(id: String) -> Dictionary:
	for g in CityData.GEAR:
		if g["id"] == id:
			return g
	return {}


func _build_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var item := _gear(_selected_id)
	if item.is_empty():
		_detail.add_child(UIKit.label("Select an item to inspect it.", 15, UIKit.TEXT_DIM))
		_detail.add_child(UIKit.wrapped("Two-step purchase rule: every item is rank-verified first. Purchase options never appear for gear whose rank requirement you do not meet.", 13))
		return
	var tcol := UIKit.tier_color(item["tier"])
	_detail.add_child(UIKit.tag(item["tier"].to_upper(), tcol, 11))
	_detail.add_child(UIKit.label(item["name"], 26, UIKit.TEXT))
	_detail.add_child(UIKit.label("Class: %s" % item["class"], 13, UIKit.TEXT_DIM))
	_detail.add_child(UIKit.wrapped(item["desc"], 14, UIKit.TEXT))
	_detail.add_child(UIKit.separator())
	if GameState.owns_gear(item["id"]):
		_detail.add_child(UIKit.label("Owned - equipped automatically on deploy.", 14, UIKit.GREEN))
		return
	# ---- Step 1: rank verification
	var required: String = item["required_rank"]
	var unlocked := RankManager.meets_rank(required)
	var step1 := UIKit.panel(UIKit.PANEL_BG_SOLID, 10, UIKit.GREEN if unlocked else UIKit.RED, 12)
	var s1 := UIKit.vbox(4)
	step1.add_child(s1)
	s1.add_child(UIKit.label("STEP 1  -  RANK VERIFICATION", 11, UIKit.TEXT_DIM))
	if unlocked:
		s1.add_child(UIKit.label("Rank %s verified. Requirement: Rank %s." % [RankManager.rank_letter(), required], 15, UIKit.GREEN))
	else:
		s1.add_child(UIKit.label("LOCKED  -  This item requires Rank %s." % required, 15, UIKit.RED))
		var need := RankManager.THRESHOLDS[RankManager.rank_index_of(required)] - RankManager.renown
		s1.add_child(UIKit.wrapped("You are Rank %s. Earn %s more Renown (defeat targets, complete jobs) to advance to Rank %s before purchase options become available." % [RankManager.rank_letter(), UIKit.fmt_int(maxi(need, 0)), required], 13))
	_detail.add_child(step1)
	if not unlocked:
		var locked := UIKit.label("Purchase options hidden until Rank %s." % required, 13, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		_detail.add_child(locked)
		return
	# ---- Step 2: purchase options (only reachable once Step 1 passed)
	if not _step2_open:
		var open_btn := UIKit.button("Open purchase options", tcol, 15, 40)
		open_btn.pressed.connect(func() -> void:
			_step2_open = true
			_build_detail())
		_detail.add_child(open_btn)
		return
	var step2 := UIKit.panel(UIKit.PANEL_BG_SOLID, 10, tcol, 12)
	var s2 := UIKit.vbox(8)
	step2.add_child(s2)
	s2.add_child(UIKit.label("STEP 2  -  PURCHASE OPTIONS", 11, UIKit.TEXT_DIM))
	var row := UIKit.hbox(10)
	var pc: int = item["price_credits"]
	var pp: int = item["price_points"]
	var iid: String = item["id"]
	var buy_c := UIKit.button("Buy for %s credits" % UIKit.fmt_int(pc), UIKit.GOLD, 14, 40)
	buy_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_c.disabled = GameState.credits < pc
	buy_c.pressed.connect(func() -> void:
		if GameState.buy_gear(iid, pc, "credits"):
			refresh())
	var buy_p := UIKit.button("Buy for %s points" % UIKit.fmt_int(pp), UIKit.ACCENT, 14, 40)
	buy_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_p.disabled = GameState.points < pp
	buy_p.pressed.connect(func() -> void:
		if GameState.buy_gear(iid, pp, "points"):
			refresh())
	row.add_child(buy_c)
	row.add_child(buy_p)
	s2.add_child(row)
	if buy_c.disabled and buy_p.disabled:
		s2.add_child(UIKit.label("Insufficient funds - earn more Credits or match Points.", 12, UIKit.RED))
	_detail.add_child(step2)
