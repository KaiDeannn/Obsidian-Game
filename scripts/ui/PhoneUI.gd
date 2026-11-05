extends CanvasLayer
class_name PhoneUI
## In-game smartphone (CanvasLayer 20). Toggled with P or the HUD icon; slides up with an
## animated overlay. Apps: Jobs (accept/track/cancel city tasks), Property (buy Heights
## plots with a confirm step), Stats (live Rank, Renown, Credits), Calls (players in the
## session: direct messages + voice calls, and the Rook Hale valet contact) and Garage
## (owned vehicles, damage, dealership).
## The call overlay lives on this layer but outside the phone body, so an incoming call
## or the valet bar can sit over the city while the phone itself stays docked.
## Hierarchy (built in code): PhoneUI -> Dim(ColorRect) ; Dock(Control) -> Phone(PanelContainer) -> Screen(VBox)
##                                    ; CallRoot(Control) -> CallOverlay(PanelContainer)

signal visibility_toggled(is_open: bool)
signal notified(text: String, color: Color)

const PHONE_SIZE := Vector2(380, 690)
const VOICE_LINES := {
	"greeting": "res://audio/rook_greeting.wav",
	"request": "res://audio/rook_request.wav",
	"return": "res://audio/rook_return.wav",
	"fix": "res://audio/rook_fix.wav",
	"ready": "res://audio/rook_ready.wav",
}

var is_open := false

var _dim: ColorRect
var _dock: Control
var _phone: PanelContainer
var _screen: VBoxContainer
var _status_time: Label
var _status_rank: Label
var _page_host: Control
var _pages: Dictionary = {}
var _tween: Tween
var _confirm_property_id := ""
var _confirm_vehicle_id := ""
var _weapons_rarity := "All"
var _battle_mode := "solo"
var _battle_map := "ruins"
var _battle_allies: Array = []

# comms
var _msg_input: LineEdit
var _msg_player_id := -1

# call overlay
var _call_root: Control
var _call_overlay: PanelContainer
var _call_avatar: PanelContainer
var _call_initials: Label
var _call_name: Label
var _call_sub: Label
var _call_state: Label
var _call_text: Label
var _call_timer: Label
var _call_meter: ProgressBar
var _call_actions: HBoxContainer
var _call_panel: VBoxContainer
var _active_call: Dictionary = {}     # {"kind": "player"|"npc", "player_id", "contact_id", "incoming"}
var _valet_mode := ""
var _call_typing: Tween
var _pulse: Tween
var _panel_refresh := 0.0

# audio
var _ring: AudioStreamPlayer
var _sfx: AudioStreamPlayer
var _voice: AudioStreamPlayer


func _ready() -> void:
	layer = 20
	_build()
	_build_call_overlay()
	_build_audio()
	_phone.position.y = PHONE_SIZE.y + 60
	_phone.modulate.a = 0.0
	_dock.visible = false
	_dim.visible = false
	_dim.modulate.a = 0.0

	JobManager.job_started.connect(func(_j: Dictionary) -> void: _refresh_if_open("jobs"))
	JobManager.job_completed.connect(func(_j: Dictionary, _c: int, _r: int) -> void: _refresh_if_open("jobs"); _refresh_if_open("stats"))
	JobManager.job_cancelled.connect(func(_j: Dictionary) -> void: _refresh_if_open("jobs"))
	GameState.credits_changed.connect(func(_v: int) -> void: _refresh_if_open("stats"); _refresh_if_open("property"); _refresh_if_open("garage"))
	GameState.premium_equipped.connect(func(_id: String) -> void: _refresh_if_open("stats"); _refresh_if_open("weapons"))
	Battle.match_ready.connect(func(_m: Dictionary) -> void: _refresh_if_open("battles"); _refresh_if_open("home"))
	Battle.match_cleared.connect(func() -> void: _refresh_if_open("battles"); _refresh_if_open("home"))
	GameState.vehicle_damage_changed.connect(func(_id: String, _d: int) -> void: _refresh_if_open("garage"); _refresh_valet_panel())
	RankManager.renown_changed.connect(func(_v: int, _g: int) -> void: _refresh_if_open("stats"))
	Session.players_changed.connect(func() -> void: _refresh_if_open("contacts"))
	Session.message_received.connect(_on_message_received)
	Session.call_state_changed.connect(_on_player_call_state)
	Session.voice_level.connect(func(level: float) -> void: _call_meter.value = level)
	Valet.state_changed.connect(func() -> void: _refresh_if_open("garage"); _refresh_valet_panel())
	Valet.vehicle_delivered.connect(_on_vehicle_delivered)
	Valet.repair_finished.connect(_on_repair_finished)


func _process(delta: float) -> void:
	if is_open:
		_status_time.text = Time.get_time_string_from_system().substr(0, 5)
	if _call_root.visible:
		if _active_call.get("kind", "") == "player" and Session.call_state == "active":
			var t := int(Session.call_duration())
			@warning_ignore("integer_division")
			_call_timer.text = "%02d:%02d" % [t / 60, t % 60]
		if _valet_mode == "fix" and not Valet.service_queue.is_empty():
			_panel_refresh += delta
			if _panel_refresh >= 0.5:
				_panel_refresh = 0.0
				_refresh_valet_panel()


# ---------------------------------------------------------------- build
func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.4)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	UIKit.full_rect(_dim)

	_dock = Control.new()
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dock)
	_dock.anchor_left = 1.0
	_dock.anchor_right = 1.0
	_dock.anchor_top = 1.0
	_dock.anchor_bottom = 1.0
	_dock.offset_left = -PHONE_SIZE.x - 24
	_dock.offset_right = -24
	_dock.offset_top = -PHONE_SIZE.y - 24
	_dock.offset_bottom = -24
	_dock.clip_contents = false

	_phone = UIKit.panel(Color(0.05, 0.05, 0.06, 1.0), 24, Color(0.3, 0.3, 0.33, 1.0), 10)
	_phone.custom_minimum_size = PHONE_SIZE
	_phone.size = PHONE_SIZE
	_dock.add_child(_phone)

	var screen_panel := UIKit.panel(Color(0.09, 0.09, 0.1, 1.0), 20, Color(1, 1, 1, 0.05), 0)
	_phone.add_child(screen_panel)
	screen_panel.clip_contents = true
	_screen = UIKit.vbox(0)
	screen_panel.add_child(_screen)

	# Status bar.
	var status := UIKit.hbox(8)
	var status_pad := MarginContainer.new()
	status_pad.add_theme_constant_override("margin_left", 18)
	status_pad.add_theme_constant_override("margin_right", 18)
	status_pad.add_theme_constant_override("margin_top", 12)
	status_pad.add_theme_constant_override("margin_bottom", 4)
	status_pad.add_child(status)
	_screen.add_child(status_pad)
	_status_time = UIKit.label("00:00", 13, UIKit.TEXT)
	status.add_child(_status_time)
	status.add_child(UIKit.spacer())
	status.add_child(UIKit.label("AETHERIS NET", 11, UIKit.ACCENT))
	status.add_child(UIKit.spacer())
	_status_rank = UIKit.label("RANK D", 12, UIKit.TEXT_DIM)
	status.add_child(_status_rank)

	# Page host.
	_page_host = Control.new()
	_page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_host.clip_contents = true
	_screen.add_child(_page_host)

	# Home bar.
	var home_bar := CenterContainer.new()
	home_bar.custom_minimum_size = Vector2(0, 34)
	var pill := ColorRect.new()
	pill.color = Color(1, 1, 1, 0.35)
	pill.custom_minimum_size = Vector2(110, 5)
	home_bar.add_child(pill)
	var home_btn := Button.new()
	home_btn.flat = true
	home_btn.focus_mode = Control.FOCUS_NONE
	home_btn.custom_minimum_size = Vector2(0, 34)
	home_btn.pressed.connect(func() -> void: show_page("home"))
	var home_wrap := Control.new()
	home_wrap.custom_minimum_size = Vector2(0, 34)
	home_wrap.add_child(home_bar)
	home_wrap.add_child(home_btn)
	UIKit.full_rect(home_bar)
	UIKit.full_rect(home_btn)
	_screen.add_child(home_wrap)

	for page_name in ["home", "jobs", "property", "stats", "contacts", "messages", "garage", "weapons", "battles"]:
		var page := UIKit.vbox(0)
		page.visible = false
		_page_host.add_child(page)
		UIKit.full_rect(page)
		_pages[page_name] = page


func _build_call_overlay() -> void:
	_call_root = Control.new()
	_call_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_call_root.visible = false
	add_child(_call_root)
	UIKit.full_rect(_call_root)
	# Leave the right-hand strip for the docked phone so the overlay never covers it.
	_call_root.offset_right = -(PHONE_SIZE.x + 48)
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_call_root.add_child(centre)
	UIKit.full_rect(centre)
	_call_overlay = UIKit.panel(Color(0.05, 0.06, 0.1, 0.96), 22, Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, 0.45), 22)
	_call_overlay.custom_minimum_size = Vector2(380, 0)
	centre.add_child(_call_overlay)
	var v := UIKit.vbox(8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_call_overlay.add_child(v)

	var avatar_wrap := CenterContainer.new()
	v.add_child(avatar_wrap)
	_call_avatar = UIKit.panel(Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, 0.16), 40, UIKit.ACCENT, 0)
	_call_avatar.custom_minimum_size = Vector2(80, 80)
	_call_avatar.pivot_offset = Vector2(40, 40)
	avatar_wrap.add_child(_call_avatar)
	_call_initials = UIKit.label("RH", 26, UIKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_call_initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_call_avatar.add_child(_call_initials)

	_call_state = UIKit.label("CALLING", 11, UIKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_call_state)
	_call_name = UIKit.label("", 24, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_call_name)
	_call_sub = UIKit.label("", 12, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_call_sub)
	_call_timer = UIKit.label("00:00", 14, UIKit.GREEN, HORIZONTAL_ALIGNMENT_CENTER)
	_call_timer.visible = false
	v.add_child(_call_timer)
	_call_meter = UIKit.progress(0.0, UIKit.GREEN, 6)
	_call_meter.custom_minimum_size = Vector2(200, 6)
	_call_meter.visible = false
	var meter_wrap := CenterContainer.new()
	meter_wrap.add_child(_call_meter)
	v.add_child(meter_wrap)
	_call_text = UIKit.wrapped("", 14, UIKit.TEXT)
	_call_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_call_text.custom_minimum_size = Vector2(330, 0)
	v.add_child(_call_text)
	_call_actions = UIKit.hbox(8)
	_call_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_call_actions)
	_call_panel = UIKit.vbox(8)
	v.add_child(_call_panel)


func _build_audio() -> void:
	_ring = AudioStreamPlayer.new()
	_ring.stream = load("res://audio/ring.wav")
	_ring.volume_db = -6.0
	_ring.finished.connect(func() -> void:
		if _call_root.visible and _active_call.get("incoming", false) and _call_state.text == "INCOMING CALL":
			_ring.play())
	add_child(_ring)
	_sfx = AudioStreamPlayer.new()
	_sfx.volume_db = -8.0
	add_child(_sfx)
	_voice = AudioStreamPlayer.new()
	_voice.volume_db = 2.0
	add_child(_voice)


func _play_sfx(path: String) -> void:
	_sfx.stream = load(path)
	_sfx.play()


## Plays one of Rook's recorded lines; returns its length so the UI can wait for it.
func _speak(line: String) -> float:
	if not VOICE_LINES.has(line):
		return 0.0
	var stream: AudioStream = load(VOICE_LINES[line])
	_voice.stream = stream
	_voice.play()
	return stream.get_length()


# ---------------------------------------------------------------- open / close
func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open(page := "home") -> void:
	if is_open:
		show_page(page)
		return
	is_open = true
	_dock.visible = true
	_dim.visible = true
	show_page(page)
	_animate(true)
	visibility_toggled.emit(true)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_animate(false)
	visibility_toggled.emit(false)


func _animate(opening: bool) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	var target_y := 0.0 if opening else PHONE_SIZE.y + 60.0
	_tween.tween_property(_phone, "position:y", target_y, 0.38).set_trans(Tween.TRANS_BACK if opening else Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if opening else Tween.EASE_IN)
	_tween.tween_property(_phone, "modulate:a", 1.0 if opening else 0.0, 0.25)
	_tween.tween_property(_dim, "modulate:a", 1.0 if opening else 0.0, 0.3)
	if not opening:
		_tween.chain().tween_callback(func() -> void:
			_dock.visible = false
			_dim.visible = false)


# ---------------------------------------------------------------- pages
func show_page(page_name: String) -> void:
	for n in _pages:
		_pages[n].visible = n == page_name
	_rebuild(page_name)
	_status_rank.text = "RANK %s" % RankManager.rank_letter()
	_status_rank.add_theme_color_override("font_color", RankManager.rank_color(RankManager.rank_letter()))


func _refresh_if_open(page_name: String) -> void:
	if is_open and _pages[page_name].visible:
		_rebuild(page_name)


func _rebuild(page_name: String) -> void:
	var page: VBoxContainer = _pages[page_name]
	for c in page.get_children():
		c.queue_free()
	match page_name:
		"home": _build_home(page)
		"jobs": _build_jobs(page)
		"property": _build_property(page)
		"stats": _build_stats(page)
		"contacts": _build_contacts(page)
		"messages": _build_messages(page)
		"garage": _build_garage(page)
		"weapons": _build_weapons(page)
		"battles": _build_battles(page)


func _header(page: VBoxContainer, title: String, subtitle: String, back_to := "home") -> void:
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_right", 18)
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_theme_constant_override("margin_bottom", 8)
	page.add_child(pad)
	var row := UIKit.hbox(10)
	pad.add_child(row)
	var back := UIKit.button("<", UIKit.ACCENT, 16, 34)
	back.custom_minimum_size = Vector2(40, 34)
	back.pressed.connect(func() -> void: show_page(back_to))
	row.add_child(back)
	var col := UIKit.vbox(0)
	col.add_child(UIKit.label(title, 20, UIKit.TEXT))
	col.add_child(UIKit.label(subtitle, 11, UIKit.TEXT_DIM))
	row.add_child(col)


func _scroll(page: VBoxContainer) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(sc)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_bottom", 12)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(pad)
	var list := UIKit.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(list)
	return list


func _card(color: Color = Color(1, 1, 1, 0.08)) -> VBoxContainer:
	var p := UIKit.panel(UIKit.CARD_BG, 14, color, 14)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UIKit.vbox(6)
	p.add_child(v)
	v.set_meta("panel", p)
	return v


func _add_card(list: VBoxContainer, card: VBoxContainer) -> void:
	list.add_child(card.get_meta("panel"))


func _section(list: VBoxContainer, text: String) -> void:
	var l := UIKit.label(text, 11, UIKit.TEXT_DIM)
	list.add_child(l)


static func _initials(full_name: String) -> String:
	var parts := full_name.split(" ", false)
	var out := ""
	for p in parts:
		if p.length() > 0:
			out += p.substr(0, 1).to_upper()
	return out.substr(0, 2)


# ---- Home
func _build_home(page: VBoxContainer) -> void:
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_right", 18)
	pad.add_theme_constant_override("margin_top", 10)
	page.add_child(pad)
	var v := UIKit.vbox(14)
	pad.add_child(v)
	var greet := _card(Color(UIKit.ACCENT2.r, UIKit.ACCENT2.g, UIKit.ACCENT2.b, 0.4))
	greet.add_child(UIKit.label("OBSIDIAN OS", 11, UIKit.ACCENT2))
	greet.add_child(UIKit.label("Operative  -  Rank %s" % RankManager.rank_letter(), 20, UIKit.TEXT))
	greet.add_child(UIKit.label("%s credits   |   %s renown" % [UIKit.fmt_int(GameState.credits), UIKit.fmt_int(RankManager.renown)], 13, UIKit.TEXT_DIM))
	if JobManager.has_active():
		greet.add_child(UIKit.label("Active job: %s" % JobManager.active_job["title"], 13, UIKit.ACCENT))
	_add_card(v, greet)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	_app_icon(grid, "JOBS", "Job board", UIKit.ACCENT, "jobs")
	_app_icon(grid, "HOMES", "Property", UIKit.GOLD, "property")
	_app_icon(grid, "STATS", "Progress", UIKit.ACCENT2, "stats")
	var unread := Session.unread_total()
	_app_icon(grid, "CALLS" if unread == 0 else "CALLS (%d)" % unread, "Contacts", UIKit.GREEN if unread == 0 else UIKit.AMBER, "contacts")
	_app_icon(grid, "GARAGE", "Vehicles", UIKit.AMBER, "garage")
	_app_icon(grid, "WEAPONS", "Arsenal", UIKit.rarity_color("Mythic"), "weapons")
	_app_icon(grid, "BATTLES" if not Battle.has_pending() else "MATCH READY", "Matches", UIKit.RED if not Battle.has_pending() else UIKit.GREEN, "battles")
	var tip := UIKit.wrapped("Tip: call Rook in CALLS and he will valet any car you own to wherever you are standing.", 12, UIKit.TEXT_DIM)
	v.add_child(tip)


func _app_icon(grid: GridContainer, glyph: String, title: String, color: Color, page_name: String) -> void:
	var col := UIKit.vbox(6)
	var b := UIKit.button(glyph, color, 15, 96)
	b.custom_minimum_size = Vector2(104, 96)
	b.pressed.connect(func() -> void: show_page(page_name))
	col.add_child(b)
	var caption := UIKit.label(title, 12, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	caption.clip_text = true
	caption.custom_minimum_size = Vector2(104, 0)
	col.add_child(caption)
	grid.add_child(col)


# ---- Jobs
func _build_jobs(page: VBoxContainer) -> void:
	_header(page, "Jobs", "Available city tasks")
	var list := _scroll(page)
	if JobManager.has_active():
		var job := JobManager.active_job
		var card := _card(Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, 0.6))
		card.add_child(UIKit.label("ACTIVE JOB", 11, UIKit.ACCENT))
		card.add_child(UIKit.label(job["title"], 18, UIKit.TEXT))
		card.add_child(UIKit.wrapped("Stage %d/%d: %s" % [JobManager.stage_index + 1, JobManager.stage_count(), JobManager.current_label()], 13, UIKit.TEXT))
		var cancel := UIKit.button("Cancel job", UIKit.RED, 13, 32)
		cancel.pressed.connect(func() -> void: JobManager.cancel_job())
		card.add_child(cancel)
		_add_card(list, card)
	for job in JobManager.jobs:
		if JobManager.is_active(job["id"]):
			continue
		var card := _card()
		var top := UIKit.hbox(8)
		top.add_child(UIKit.label(job["title"], 17, UIKit.TEXT))
		top.add_child(UIKit.spacer())
		var done := JobManager.times_completed(job["id"])
		if done > 0:
			top.add_child(UIKit.tag("DONE x%d" % done, UIKit.GREEN, 10))
		card.add_child(top)
		card.add_child(UIKit.label(job["client"], 11, UIKit.ACCENT2))
		card.add_child(UIKit.wrapped(job["desc"], 13))
		var rewards := UIKit.hbox(10)
		rewards.add_child(UIKit.tag("+%s cr" % UIKit.fmt_int(job["credits"]), UIKit.GOLD, 11))
		rewards.add_child(UIKit.tag("+%d renown" % job["renown"], UIKit.ACCENT2, 11))
		rewards.add_child(UIKit.tag("%d stops" % job["stages"].size(), UIKit.TEXT_DIM, 11))
		card.add_child(rewards)
		var accept := UIKit.button("Accept job", UIKit.ACCENT, 14, 34)
		accept.disabled = JobManager.has_active()
		var jid: String = job["id"]
		accept.pressed.connect(func() -> void:
			if JobManager.start_job(jid):
				close())
		card.add_child(accept)
		_add_card(list, card)


# ---- Property
func _build_property(page: VBoxContainer) -> void:
	_header(page, "Property", "The Heights  -  listings")
	var list := _scroll(page)
	var wallet := UIKit.label("Wallet: %s credits" % UIKit.fmt_int(GameState.credits), 13, UIKit.GOLD)
	list.add_child(wallet)
	for prop in CityData.PROPERTIES:
		var pid: String = prop["id"]
		var owned := GameState.owns_property(pid)
		var card := _card(Color(UIKit.GREEN.r, UIKit.GREEN.g, UIKit.GREEN.b, 0.5) if owned else Color(1, 1, 1, 0.08))
		var top := UIKit.hbox(8)
		top.add_child(UIKit.label(prop["name"], 17, UIKit.TEXT))
		top.add_child(UIKit.spacer())
		top.add_child(UIKit.tag("OWNED" if owned else "%s cr" % UIKit.fmt_int(prop["price"]), UIKit.GREEN if owned else UIKit.GOLD, 11))
		card.add_child(top)
		card.add_child(UIKit.label(prop["district"], 11, UIKit.ACCENT))
		card.add_child(UIKit.wrapped(prop["perk"], 13))
		if not owned:
			if _confirm_property_id == pid:
				card.add_child(UIKit.wrapped("Confirm purchase of %s for %s credits?" % [prop["name"], UIKit.fmt_int(prop["price"])], 13, UIKit.TEXT))
				var row := UIKit.hbox(8)
				var yes := UIKit.button("Confirm", UIKit.GREEN, 13, 32)
				yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var no := UIKit.button("Back", UIKit.TEXT_DIM, 13, 32)
				no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var price: int = prop["price"]
				yes.pressed.connect(func() -> void:
					_confirm_property_id = ""
					if GameState.buy_property(pid, price):
						_rebuild("property")
					else:
						_rebuild("property")
						_flash_error("Insufficient credits"))
				no.pressed.connect(func() -> void:
					_confirm_property_id = ""
					_rebuild("property"))
				row.add_child(yes)
				row.add_child(no)
				card.add_child(row)
			else:
				var buy := UIKit.button("Buy property", UIKit.GOLD, 14, 34)
				buy.disabled = GameState.credits < prop["price"]
				if buy.disabled:
					buy.text = "Buy property  (need %s more)" % UIKit.fmt_int(prop["price"] - GameState.credits)
				buy.pressed.connect(func() -> void:
					_confirm_property_id = pid
					_rebuild("property"))
				card.add_child(buy)
		_add_card(list, card)


func _flash_error(text: String) -> void:
	var l := UIKit.label(text, 13, UIKit.RED, HORIZONTAL_ALIGNMENT_CENTER)
	_screen.add_child(l)
	_screen.move_child(l, 1)
	var tw := l.create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


# ---- Stats
func _build_stats(page: VBoxContainer) -> void:
	_header(page, "Stats", "Live operative status")
	var list := _scroll(page)
	var letter := RankManager.rank_letter()
	var color := RankManager.rank_color(letter)
	var rank_card := _card(Color(color.r, color.g, color.b, 0.5))
	var row := UIKit.hbox(16)
	var badge := UIKit.panel(Color(color.r, color.g, color.b, 0.18), 40, color, 0)
	badge.custom_minimum_size = Vector2(80, 80)
	var big := UIKit.label(letter, 44, color, HORIZONTAL_ALIGNMENT_CENTER)
	big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(big)
	row.add_child(badge)
	var col := UIKit.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label("CURRENT RANK", 11, UIKit.TEXT_DIM))
	col.add_child(UIKit.label("Rank %s" % letter, 22, UIKit.TEXT))
	var nxt := RankManager.next_threshold()
	if nxt > 0:
		col.add_child(UIKit.label("%s / %s renown to Rank %s" % [UIKit.fmt_int(RankManager.renown), UIKit.fmt_int(nxt), RankManager.RANKS[RankManager.rank_index + 1]], 12, UIKit.TEXT_DIM))
		col.add_child(UIKit.progress(RankManager.progress_ratio(), color, 8))
	else:
		col.add_child(UIKit.label("Maximum rank achieved", 12, UIKit.TEXT_DIM))
	row.add_child(col)
	rank_card.add_child(row)
	_add_card(list, rank_card)

	_stat_row(list, "Renown", UIKit.fmt_int(RankManager.renown), UIKit.ACCENT2)
	_stat_row(list, "Credits", UIKit.fmt_int(GameState.credits), UIKit.GOLD)
	_stat_row(list, "Match points", UIKit.fmt_int(GameState.points), UIKit.ACCENT)
	_stat_row(list, "Combat class", GameState.selected_class, UIKit.TEXT)
	_stat_row(list, "Jobs completed", str(GameState.jobs_completed), UIKit.TEXT)
	_stat_row(list, "Spire takedowns", str(GameState.kills), UIKit.TEXT)
	var wins := 0
	for r in Battle.history:
		if r["won"]:
			wins += 1
	_stat_row(list, "Battles won", "%d / %d" % [wins, Battle.history.size()], UIKit.RED)
	_stat_row(list, "Properties owned", str(GameState.owned_properties.size()), UIKit.GREEN)
	_stat_row(list, "Vehicles owned", str(GameState.owned_vehicles.size()), UIKit.AMBER)
	_stat_row(list, "Gear owned", str(GameState.owned_gear.size()), UIKit.TEXT)
	_stat_row(list, "Engineer weapon", str(GameState.equipped_weapon()["name"]), UIKit.TEXT)


func _stat_row(list: VBoxContainer, title: String, value: String, color: Color) -> void:
	var card := _card()
	var row := UIKit.hbox(8)
	row.add_child(UIKit.label(title, 14, UIKit.TEXT_DIM))
	row.add_child(UIKit.spacer())
	row.add_child(UIKit.label(value, 16, color))
	card.add_child(row)
	_add_card(list, card)


# ================================================================ CALLS: contacts
func _build_contacts(page: VBoxContainer) -> void:
	_header(page, "Contacts", "Players in your session and people you work with")
	var list := _scroll(page)
	var ids: Array = Session.player_ids()
	_section(list, "PLAYERS IN SESSION (%d)" % ids.size())
	if ids.is_empty():
		list.add_child(UIKit.wrapped("No other players connected yet. Everyone who joins the session shows up here automatically.", 12))
	for id in ids:
		var pid: int = id
		var p: Dictionary = Session.players[pid]
		var on_call := Session.active_call_id == pid and Session.call_state != "idle"
		var card := _card(Color(UIKit.GREEN.r, UIKit.GREEN.g, UIKit.GREEN.b, 0.5) if on_call else Color(1, 1, 1, 0.08))
		var row := UIKit.hbox(10)
		row.add_child(_avatar(_initials(p["name"]), UIKit.ACCENT))
		var col := UIKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var top := UIKit.hbox(6)
		top.add_child(UIKit.label(p["name"], 15, UIKit.TEXT))
		var n_unread := int(Session.unread.get(pid, 0))
		if n_unread > 0:
			top.add_child(UIKit.tag("%d NEW" % n_unread, UIKit.AMBER, 10))
		if on_call:
			top.add_child(UIKit.tag("ON CALL", UIKit.GREEN, 10))
		col.add_child(top)
		col.add_child(UIKit.label("%s  -  Rank %s  -  online" % [p["class"], p["rank"]], 11, UIKit.TEXT_DIM))
		row.add_child(col)
		card.add_child(row)
		var actions := UIKit.hbox(8)
		var msg := UIKit.button("Message", UIKit.ACCENT, 13, 32)
		msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		msg.pressed.connect(func() -> void: open_messages(pid))
		actions.add_child(msg)
		var call := UIKit.button("Call", UIKit.GREEN, 13, 32)
		call.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		call.disabled = Session.call_state != "idle" or not _active_call.is_empty()
		call.pressed.connect(func() -> void: call_player(pid))
		actions.add_child(call)
		card.add_child(actions)
		_add_card(list, card)

	_section(list, "CONTACTS")
	for ct in CityData.CONTACTS:
		var cid: String = ct["id"]
		var card := _card(Color(UIKit.AMBER.r, UIKit.AMBER.g, UIKit.AMBER.b, 0.45))
		var row := UIKit.hbox(10)
		row.add_child(_avatar(_initials(ct["name"]), UIKit.AMBER))
		var col := UIKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var top := UIKit.hbox(6)
		top.add_child(UIKit.label(ct["name"], 15, UIKit.TEXT))
		top.add_child(UIKit.tag(ct["tag"], UIKit.AMBER, 10))
		col.add_child(top)
		col.add_child(UIKit.label(ct["role"], 11, UIKit.AMBER))
		row.add_child(col)
		card.add_child(row)
		var call := UIKit.button("Call %s" % ct["name"].split(" ")[0], UIKit.AMBER, 13, 32)
		call.disabled = Session.call_state != "idle" or not _active_call.is_empty()
		call.pressed.connect(func() -> void: call_contact(cid))
		card.add_child(call)
		_add_card(list, card)


func _avatar(initials: String, color: Color) -> PanelContainer:
	var a := UIKit.panel(Color(color.r, color.g, color.b, 0.16), 22, color, 0)
	a.custom_minimum_size = Vector2(44, 44)
	var l := UIKit.label(initials, 14, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	a.add_child(l)
	return a


# ================================================================ CALLS: messages
func open_messages(player_id: int) -> void:
	_msg_player_id = player_id
	Session.mark_read(player_id)
	open("messages")


func _build_messages(page: VBoxContainer) -> void:
	if not Session.players.has(_msg_player_id):
		_header(page, "Messages", "Pick a player in Contacts to start a thread", "contacts")
		return
	var p: Dictionary = Session.players[_msg_player_id]
	_header(page, p["name"], "%s  -  Rank %s  -  direct messages" % [p["class"], p["rank"]], "contacts")
	var list := _scroll(page)
	var thread: Array = Session.threads.get(_msg_player_id, [])
	if thread.is_empty():
		list.add_child(UIKit.wrapped("Say hello. Messages go straight to this player's phone.", 12))
	for m in thread:
		var mine: bool = m["from_me"]
		var bubble := UIKit.panel(Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, 0.28) if mine else UIKit.CARD_BG, 12, Color(1, 1, 1, 0.08), 10)
		bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if mine else Control.SIZE_SHRINK_BEGIN
		var v := UIKit.vbox(2)
		var txt := UIKit.wrapped(m["text"], 13, UIKit.TEXT)
		txt.custom_minimum_size = Vector2(220, 0)
		v.add_child(txt)
		v.add_child(UIKit.label(m["time"], 9, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT if mine else HORIZONTAL_ALIGNMENT_LEFT))
		bubble.add_child(v)
		list.add_child(bubble)
	var sc := list.get_parent().get_parent() as ScrollContainer
	if sc:
		sc.call_deferred("set_v_scroll", 100000)
	# composer pinned under the thread
	var pad := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_bottom"]:
		pad.add_theme_constant_override(side, 12)
	pad.add_theme_constant_override("margin_top", 6)
	var row := UIKit.hbox(6)
	_msg_input = LineEdit.new()
	_msg_input.placeholder_text = "Type a message"
	_msg_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_msg_input.custom_minimum_size = Vector2(0, 34)
	_msg_input.add_theme_font_size_override("font_size", 13)
	_msg_input.text_submitted.connect(func(_t: String) -> void: _send_message())
	row.add_child(_msg_input)
	var send := UIKit.button("Send", UIKit.ACCENT, 13, 34)
	send.custom_minimum_size = Vector2(64, 34)
	send.pressed.connect(_send_message)
	row.add_child(send)
	pad.add_child(row)
	page.add_child(pad)
	_msg_input.call_deferred("grab_focus")


func _send_message() -> void:
	if _msg_input == null:
		return
	if Session.send_text(_msg_player_id, _msg_input.text):
		_rebuild("messages")


func _on_message_received(player_id: int, text: String) -> void:
	_play_sfx("res://audio/ping.wav")
	if is_open and _pages["messages"].visible and _msg_player_id == player_id:
		Session.mark_read(player_id)
		_rebuild("messages")
		return
	notified.emit("%s: %s" % [Session.player_name(player_id), text], UIKit.ACCENT)
	_refresh_if_open("contacts")
	_refresh_if_open("home")


# ================================================================ CALLS: player voice calls
func call_player(player_id: int) -> void:
	if Session.call_state != "idle" or not _active_call.is_empty():
		return
	if Session.start_call(player_id):
		_active_call = {"kind": "player", "player_id": player_id, "incoming": false}
		_show_call_overlay()


func _on_player_call_state(player_id: int, state: String) -> void:
	match state:
		"ringing":
			if not _active_call.is_empty():
				return
			_active_call = {"kind": "player", "player_id": player_id, "incoming": true}
			if not is_open:
				open("contacts")
			_show_call_overlay()
		"active":
			if _active_call.get("player_id", -1) == player_id:
				_show_player_call_active()
		"ended", "declined", "busy":
			if _active_call.get("player_id", -1) == player_id:
				_call_state.text = {"ended": "CALL ENDED", "declined": "DECLINED", "busy": "BUSY"}[state]
				_pulse_avatar(false)
				get_tree().create_timer(0.7, true).timeout.connect(func() -> void:
					# only close if this player call is still the one on screen
					if _active_call.get("player_id", -1) == player_id:
						_close_call_overlay())
			if state == "declined":
				notified.emit("%s declined your call." % Session.player_name(player_id), UIKit.RED)
	_refresh_if_open("contacts")


func _show_player_call_active() -> void:
	_ring.stop()
	_play_sfx("res://audio/connect.wav")
	_pulse_avatar(false)
	_call_state.text = "ON CALL"
	_call_timer.visible = true
	_call_meter.visible = true
	_type_text("Voice call connected." if Session.mic_available() else "Voice call connected. No microphone on this device, the meter shows the simulated feed.")
	_clear_actions()
	var mute := UIKit.button("Mute", UIKit.TEXT_DIM, 14, 40)
	mute.custom_minimum_size = Vector2(110, 40)
	mute.pressed.connect(func() -> void:
		mute.text = "Unmute" if Session.toggle_mute() else "Mute")
	_call_actions.add_child(mute)
	var end := UIKit.button("End call", UIKit.RED, 14, 40)
	end.custom_minimum_size = Vector2(120, 40)
	end.pressed.connect(_end_call)
	_call_actions.add_child(end)


# ================================================================ CALLS: NPC contacts (Rook)
## Outgoing call to a saved contact. Rook picks up, speaks his greeting, then the valet bar
## (Request / Fix / Return) appears, exactly as the design document describes.
func call_contact(contact_id: String) -> void:
	if Session.call_state != "idle" or not _active_call.is_empty():
		return
	var ct := _contact(contact_id)
	if ct.is_empty():
		return
	_active_call = {"kind": "npc", "contact_id": contact_id, "incoming": false}
	_show_call_overlay()
	get_tree().create_timer(1.3, true).timeout.connect(func() -> void:
		if _active_call.get("contact_id", "") == contact_id and _call_state.text == "CALLING":
			_npc_answered(ct["greeting"], "greeting"))


## Rook rings the player (repair done). Answering plays his line and shows the valet bar.
func incoming_call(contact_id: String, text: String, voice_line := "") -> void:
	var ct := _contact(contact_id)
	if ct.is_empty():
		return
	if Session.call_state != "idle" or not _active_call.is_empty():
		notified.emit("%s: %s" % [ct["name"], text], UIKit.AMBER)
		return
	_active_call = {"kind": "npc", "contact_id": contact_id, "incoming": true, "text": text, "voice": voice_line}
	if not is_open:
		open("garage")
	_show_call_overlay()


func _npc_answered(text: String, voice_line: String) -> void:
	_ring.stop()
	_play_sfx("res://audio/connect.wav")
	_pulse_avatar(false)
	_call_state.text = "ON CALL"
	_clear_actions()
	var length := _speak(voice_line)
	_type_text(text, maxf(length - 0.3, 1.2))
	var cid: String = _active_call.get("contact_id", "")
	get_tree().create_timer(maxf(length, 1.4), true).timeout.connect(func() -> void:
		if _active_call.get("contact_id", "") == cid and cid == "mechanic":
			_show_valet_bar())


func _contact(contact_id: String) -> Dictionary:
	for ct in CityData.CONTACTS:
		if ct["id"] == contact_id:
			return ct
	return {}


# ================================================================ call overlay
func _show_call_overlay() -> void:
	_valet_mode = ""
	_clear_panel()
	_clear_actions()
	_call_timer.visible = false
	_call_meter.visible = false
	_call_meter.value = 0.0
	var incoming: bool = _active_call.get("incoming", false)
	var kind: String = _active_call.get("kind", "npc")
	var accent := UIKit.ACCENT
	if kind == "player":
		var p: Dictionary = Session.players.get(_active_call["player_id"], {"name": "Player", "class": "?", "rank": "?"})
		_call_name.text = p["name"]
		_call_sub.text = "%s  -  Rank %s  -  in session" % [p["class"], p["rank"]]
		_call_initials.text = _initials(p["name"])
		_call_text.text = "Incoming voice call" if incoming else "Ringing..."
	else:
		var ct := _contact(_active_call["contact_id"])
		accent = UIKit.AMBER
		_call_name.text = ct["name"]
		_call_sub.text = ct["role"]
		_call_initials.text = _initials(ct["name"])
		_call_text.text = ("%s is calling you" % ct["name"]) if incoming else "Ringing..."
	_call_text.visible_characters = -1
	_call_state.text = "INCOMING CALL" if incoming else "CALLING"
	_call_initials.add_theme_color_override("font_color", accent)
	_call_state.add_theme_color_override("font_color", accent)
	_call_avatar.add_theme_stylebox_override("panel", UIKit.panel_style(Color(accent.r, accent.g, accent.b, 0.16), 40, accent, 1, 0))
	_call_overlay.add_theme_stylebox_override("panel", UIKit.panel_style(Color(0.05, 0.06, 0.1, 0.96), 22, Color(accent.r, accent.g, accent.b, 0.45), 1, 22))
	if incoming:
		var answer := UIKit.button("Answer", UIKit.GREEN, 14, 40)
		answer.custom_minimum_size = Vector2(120, 40)
		answer.pressed.connect(_answer_call)
		_call_actions.add_child(answer)
		var decline := UIKit.button("Decline", UIKit.RED, 14, 40)
		decline.custom_minimum_size = Vector2(120, 40)
		decline.pressed.connect(_end_call)
		_call_actions.add_child(decline)
		_ring.play()
	else:
		var cancel := UIKit.button("Cancel", UIKit.RED, 14, 40)
		cancel.custom_minimum_size = Vector2(140, 40)
		cancel.pressed.connect(_end_call)
		_call_actions.add_child(cancel)
	_call_root.visible = true
	_call_overlay.modulate.a = 0.0
	_call_overlay.create_tween().tween_property(_call_overlay, "modulate:a", 1.0, 0.25)
	_pulse_avatar(true)


func _answer_call() -> void:
	if _active_call.get("kind", "npc") == "player":
		Session.accept_call()
	else:
		var ct := _contact(_active_call.get("contact_id", ""))
		_npc_answered(str(_active_call.get("text", ct.get("greeting", ""))), str(_active_call.get("voice", "greeting")))


func _end_call() -> void:
	if _active_call.get("kind", "npc") == "player" and Session.call_state != "idle":
		if Session.call_state == "ringing":
			Session.decline_call()
		else:
			Session.end_call()
	_close_call_overlay()


func _close_call_overlay() -> void:
	_ring.stop()
	_voice.stop()
	_pulse_avatar(false)
	if _call_typing and _call_typing.is_valid():
		_call_typing.kill()
	_call_root.visible = false
	_call_timer.visible = false
	_call_meter.visible = false
	_valet_mode = ""
	_active_call = {}
	_refresh_if_open("contacts")
	_refresh_if_open("garage")


func _clear_actions() -> void:
	for c in _call_actions.get_children():
		_call_actions.remove_child(c)
		c.queue_free()


func _clear_panel() -> void:
	for c in _call_panel.get_children():
		_call_panel.remove_child(c)
		c.queue_free()


func _pulse_avatar(on: bool) -> void:
	if _pulse and _pulse.is_valid():
		_pulse.kill()
	_call_avatar.scale = Vector2.ONE
	if on:
		_pulse = _call_avatar.create_tween().set_loops()
		_pulse.tween_property(_call_avatar, "scale", Vector2(1.08, 1.08), 0.5).set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(_call_avatar, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


func _type_text(text: String, duration := 1.2) -> void:
	if _call_typing and _call_typing.is_valid():
		_call_typing.kill()
	_call_text.text = text
	_call_text.visible_characters = 0
	_call_typing = _call_text.create_tween()
	_call_typing.tween_property(_call_text, "visible_characters", text.length(), duration)


# ================================================================ valet bar (Request / Fix / Return)
func _show_valet_bar() -> void:
	_clear_actions()
	_valet_mode = ""
	_clear_panel()
	for entry in [["Request", "request", UIKit.GREEN], ["Fix", "fix", UIKit.AMBER], ["Return", "return", UIKit.ACCENT]]:
		var b := UIKit.button(entry[0], entry[2], 14, 40)
		b.custom_minimum_size = Vector2(92, 40)
		var mode: String = entry[1]
		b.pressed.connect(func() -> void: _set_valet_mode(mode))
		_call_actions.add_child(b)
	var end := UIKit.button("End", UIKit.RED, 14, 40)
	end.custom_minimum_size = Vector2(70, 40)
	end.pressed.connect(_end_call)
	_call_actions.add_child(end)


func _set_valet_mode(mode: String) -> void:
	_valet_mode = mode
	_refresh_valet_panel()


func _refresh_valet_panel() -> void:
	if not _call_root.visible or _valet_mode == "":
		return
	_clear_panel()
	_call_panel.add_child(UIKit.separator())
	match _valet_mode:
		"request":
			_call_panel.add_child(UIKit.label("REQUEST  -  which car do you want?", 11, UIKit.GREEN))
			for vid in GameState.owned_vehicles:
				var blocker := Valet.request_blocker(vid)
				_valet_row(vid, "Send" if blocker == "" else "", blocker, UIKit.GREEN, func() -> void:
					if Valet.request(vid):
						_say("On my way. Give me about %s, I'll bring the %s right to you." % [Valet.fmt_seconds(Valet.last_delivery_eta), GameState.vehicle_info(vid)["name"]], "request")
						_refresh_valet_panel())
		"return":
			_call_panel.add_child(UIKit.label("RETURN  -  send a car back to the garage", 11, UIKit.ACCENT))
			var any := false
			for vid in GameState.owned_vehicles:
				var st := Valet.status(vid)
				if st == "with you" or st == "en route":
					any = true
					_valet_row(vid, "Return", "", UIKit.ACCENT, func() -> void:
						if Valet.return_vehicle(vid):
							_say("Done. The %s is back in the garage." % GameState.vehicle_info(vid)["name"], "return")
							_refresh_valet_panel())
			if not any:
				_call_panel.add_child(UIKit.wrapped("Nothing of yours is out on the street right now.", 12))
		"fix":
			_call_panel.add_child(UIKit.label("FIX  -  repairs run in my service queue", 11, UIKit.AMBER))
			var any := false
			for vid in GameState.owned_vehicles:
				var dmg := GameState.vehicle_damage_of(vid)
				if Valet.in_service(vid):
					any = true
					var rem := Valet.repair_remaining(vid)
					_valet_row(vid, "", "On the lift  -  %s left" % Valet.fmt_seconds(rem) if rem > 0.0 else "Queued", UIKit.AMBER, Callable())
				elif dmg > 0 and not Valet.en_route.has(vid):
					any = true
					_valet_row(vid, "Fix (%s)" % Valet.fmt_seconds(Valet.repair_seconds_for(vid)), "", UIKit.AMBER, func() -> void:
						if Valet.fix(vid):
							_say("Putting the %s on the lift. I'll call you when it's ready." % GameState.vehicle_info(vid)["name"], "fix")
							_refresh_valet_panel())
			if not any:
				_call_panel.add_child(UIKit.wrapped("Everything you own is in one piece. Bring me something broken.", 12))


func _valet_row(vid: String, button_text: String, note: String, color: Color, on_press: Callable) -> void:
	var info := GameState.vehicle_info(vid)
	var row := UIKit.hbox(8)
	var col := UIKit.vbox(1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(info["name"], 14, UIKit.TEXT))
	var dmg := GameState.vehicle_damage_of(vid)
	var status := "%s  -  %s" % [Valet.status(vid), ("%d%% damage" % dmg) if dmg > 0 else "pristine"]
	col.add_child(UIKit.label(status if note == "" else note, 10, UIKit.TEXT_DIM if note == "" else color))
	row.add_child(col)
	if button_text != "":
		var b := UIKit.button(button_text, color, 12, 30)
		b.custom_minimum_size = Vector2(80, 30)
		b.pressed.connect(on_press)
		row.add_child(b)
	_call_panel.add_child(row)


func _say(text: String, voice_line := "") -> void:
	_speak(voice_line)
	_type_text(text, 1.0)


func _on_vehicle_delivered(vehicle_id: String, _vehicle: Node3D) -> void:
	notified.emit("%s is parked beside you. Press E to get in." % GameState.vehicle_info(vehicle_id)["name"], UIKit.GREEN)
	_refresh_valet_panel()


func _on_repair_finished(vehicle_id: String) -> void:
	var vname: String = GameState.vehicle_info(vehicle_id)["name"]
	if _active_call.get("contact_id", "") == "mechanic":
		_say("Your %s is done, good as new. Want me to send it over?" % vname, "ready")
		_refresh_valet_panel()
		return
	incoming_call("mechanic", "Rook here. Your %s is fixed, good as new. Want me to send it over?" % vname, "ready")


# ================================================================ GARAGE
func _build_garage(page: VBoxContainer) -> void:
	_header(page, "Garage", "Your vehicles, damage and the dealership")
	var list := _scroll(page)
	_section(list, "OWNED VEHICLES (%d)" % GameState.owned_vehicles.size())
	for vid in GameState.owned_vehicles:
		var info := GameState.vehicle_info(vid)
		var st := Valet.status(vid)
		var dmg := GameState.vehicle_damage_of(vid)
		var color := UIKit.GREEN if st == "with you" else (UIKit.AMBER if st != "garaged" else Color(1, 1, 1, 0.08))
		var card := _card(Color(color.r, color.g, color.b, 0.5) if st != "garaged" else color)
		var top := UIKit.hbox(8)
		var swatch := ColorRect.new()
		swatch.color = info["paint"]
		swatch.custom_minimum_size = Vector2(18, 18)
		top.add_child(swatch)
		top.add_child(UIKit.label(info["name"], 16, UIKit.TEXT))
		top.add_child(UIKit.spacer())
		top.add_child(UIKit.tag(st.to_upper(), UIKit.GREEN if st == "with you" else (UIKit.AMBER if st != "garaged" else UIKit.TEXT_DIM), 10))
		card.add_child(top)
		if Valet.in_service(vid):
			card.add_child(UIKit.label("Repair: %s remaining" % Valet.fmt_seconds(Valet.repair_remaining(vid)), 12, UIKit.AMBER))
		var dmg_row := UIKit.hbox(8)
		dmg_row.add_child(UIKit.label("Condition", 11, UIKit.TEXT_DIM))
		var bar := UIKit.progress(1.0 - dmg / 100.0, UIKit.GREEN if dmg < 35 else (UIKit.AMBER if dmg < 70 else UIKit.RED), 8)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dmg_row.add_child(bar)
		dmg_row.add_child(UIKit.label("%d%%" % (100 - dmg), 11, UIKit.TEXT_DIM))
		card.add_child(dmg_row)
		_add_card(list, card)
	var rook := UIKit.button("Call Rook  -  valet & mechanic", UIKit.AMBER, 14, 36)
	rook.disabled = Session.call_state != "idle" or not _active_call.is_empty()
	rook.pressed.connect(func() -> void: call_contact("mechanic"))
	list.add_child(rook)

	_section(list, "DEALERSHIP")
	list.add_child(UIKit.label("Wallet: %s credits" % UIKit.fmt_int(GameState.credits), 12, UIKit.GOLD))
	for v in CityData.VEHICLES:
		var vid: String = v["id"]
		if GameState.owns_vehicle(vid):
			continue
		var card := _card()
		var top := UIKit.hbox(8)
		var swatch := ColorRect.new()
		swatch.color = v["paint"]
		swatch.custom_minimum_size = Vector2(18, 18)
		top.add_child(swatch)
		top.add_child(UIKit.label(v["name"], 16, UIKit.TEXT))
		top.add_child(UIKit.spacer())
		top.add_child(UIKit.tag("%s cr" % UIKit.fmt_int(v["price"]), UIKit.GOLD, 10))
		card.add_child(top)
		card.add_child(UIKit.wrapped(v["desc"], 12))
		var price: int = v["price"]
		if _confirm_vehicle_id == vid:
			card.add_child(UIKit.wrapped("Buy the %s for %s credits? Rook will deliver it." % [v["name"], UIKit.fmt_int(price)], 12, UIKit.TEXT))
			var row := UIKit.hbox(8)
			var yes := UIKit.button("Confirm", UIKit.GREEN, 13, 32)
			yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			yes.pressed.connect(func() -> void:
				_confirm_vehicle_id = ""
				if GameState.buy_vehicle(vid, price):
					notified.emit("Bought the %s. Rook is bringing it over." % v["name"], UIKit.GOLD)
					get_tree().create_timer(1.5, true).timeout.connect(func() -> void:
						if Valet.request_blocker(vid) == "":
							Valet.request(vid))
				else:
					_flash_error("Insufficient credits")
				_rebuild("garage"))
			var no := UIKit.button("Back", UIKit.TEXT_DIM, 13, 32)
			no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			no.pressed.connect(func() -> void:
				_confirm_vehicle_id = ""
				_rebuild("garage"))
			row.add_child(yes)
			row.add_child(no)
			card.add_child(row)
		else:
			var buy := UIKit.button("Buy", UIKit.GOLD, 13, 32)
			buy.disabled = GameState.credits < price
			if buy.disabled:
				buy.text = "Buy  (need %s more)" % UIKit.fmt_int(price - GameState.credits)
			buy.pressed.connect(func() -> void:
				_confirm_vehicle_id = vid
				_rebuild("garage"))
			card.add_child(buy)
		_add_card(list, card)


# ================================================================ WEAPONS (Engineer Legendary & Mythic)
func _build_weapons(page: VBoxContainer) -> void:
	_header(page, "Weapons", "Engineer  -  Legendary & Mythic")
	var list := _scroll(page)
	var eqw := GameState.equipped_weapon()
	var hero := _card(Color(UIKit.GREEN.r, UIKit.GREEN.g, UIKit.GREEN.b, 0.6))
	hero.add_child(UIKit.label("EQUIPPED  -  3D MODEL", 11, UIKit.GREEN))
	hero.add_child(_weapon_viewer(eqw))
	hero.add_child(UIKit.label("%s  -  %s" % [eqw["name"], eqw["type"]], 15, UIKit.TEXT))
	hero.add_child(UIKit.wrapped("Deploy as Engineer in the Spire to use it (Q switches weapons there). It rides on your back in the city.", 11, UIKit.TEXT_DIM))
	_add_card(list, hero)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	for opt in CityData.PREMIUM_RARITIES:
		var value: String = opt
		var b := UIKit.button(value, UIKit.rarity_color(value) if value != "All" else UIKit.ACCENT, 12, 28)
		b.disabled = value == _weapons_rarity
		b.pressed.connect(func() -> void:
			_weapons_rarity = value
			_rebuild("weapons"))
		chips.add_child(b)
	list.add_child(chips)
	for w in CityData.PREMIUM_WEAPONS:
		if _weapons_rarity != "All" and w["rarity"] != _weapons_rarity:
			continue
		var wid: String = w["id"]
		var rcol := UIKit.rarity_color(w["rarity"])
		var equipped := GameState.equipped_premium == wid
		var card := _card(Color(UIKit.GREEN.r, UIKit.GREEN.g, UIKit.GREEN.b, 0.6) if equipped else Color(rcol.r, rcol.g, rcol.b, 0.5))
		var art := TextureRect.new()
		art.texture = load(w["image"])
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2(0, 150)
		card.add_child(art)
		var top := UIKit.hbox(6)
		top.add_child(UIKit.label(w["name"], 16, UIKit.TEXT))
		top.add_child(UIKit.spacer())
		if equipped:
			top.add_child(UIKit.tag("EQUIPPED", UIKit.GREEN, 10))
		top.add_child(UIKit.tag(str(w["rarity"]).to_upper(), rcol, 10))
		card.add_child(top)
		card.add_child(UIKit.label(w["type"], 11, UIKit.TEXT_DIM))
		var meta := UIKit.hbox(6)
		meta.add_child(UIKit.tag(CityData.PREMIUM_CLASS.to_upper(), UIKit.TEXT_DIM, 10))
		meta.add_child(UIKit.tag("DMG %d-%d" % [int(w["damage_min"]), int(w["damage_max"])], UIKit.RED, 10))
		meta.add_child(UIKit.tag(WeaponModels.kind(w).to_upper(), UIKit.TEXT_DIM, 10))
		if w["limited"]:
			meta.add_child(UIKit.tag("LIMITED RELEASE", UIKit.AMBER, 10))
		card.add_child(meta)
		card.add_child(UIKit.wrapped(w["desc"], 12))
		card.add_child(UIKit.wrapped(w["trait_desc"], 11, rcol))
		var eq := UIKit.button("Equipped" if equipped else "Equip", UIKit.GREEN if equipped else rcol, 13, 32)
		eq.disabled = equipped
		eq.pressed.connect(func() -> void:
			GameState.equip_premium(wid)
			notified.emit("%s equipped." % w["name"], rcol)
			_rebuild("weapons"))
		card.add_child(eq)
		_add_card(list, card)


## The weapon's real in-game model turning slowly on a lit stage.
func _weapon_viewer(w: Dictionary) -> SubViewportContainer:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(0, 190)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	box.add_child(vp)
	var turntable := WeaponModels.stage(vp, w, PI * 0.5 if WeaponModels.is_launcher(w) else 0.0, 1.7)
	var spin := turntable.create_tween().set_loops()
	spin.tween_property(turntable, "rotation:y", TAU, 9.0).as_relative()
	return box


# ================================================================ BATTLES (match setup)
func _build_battles(page: VBoxContainer) -> void:
	_header(page, "Battles", "Solo battles, tournaments and clan wars  -  Rank %s only" % RankManager.rank_letter())
	var list := _scroll(page)
	if Battle.has_pending():
		var m := Battle.pending
		var card := _card(Color(UIKit.GREEN.r, UIKit.GREEN.g, UIKit.GREEN.b, 0.6))
		card.add_child(UIKit.label("MATCH READY", 11, UIKit.GREEN))
		card.add_child(UIKit.label("%s  -  %s" % [m["mode_name"], m["map_name"]], 18, UIKit.TEXT))
		card.add_child(UIKit.wrapped(m["message"], 13, UIKit.TEXT))
		card.add_child(UIKit.wrapped("Map: %s." % m["map_rule"], 11, UIKit.TEXT_DIM))
		var opp_names: Array = []
		for o in m["opponents"]:
			opp_names.append("%s (%s, Rank %s)" % [o["name"], o["class"], o["rank"]])
		card.add_child(UIKit.wrapped(("Opponents: " if m["opponents"].size() > 1 else "Opponent: ") + ", ".join(opp_names), 12))
		if not m["allies"].is_empty():
			var ally_names: Array = []
			for a in m["allies"]:
				ally_names.append("%s (%s)" % [a["name"], a["class"]])
			card.add_child(UIKit.wrapped("Your side: you, " + ", ".join(ally_names), 12))
		card.add_child(UIKit.wrapped("Your portal is the Spire Gate at the north edge of the city. Press E there to enter.", 12, UIKit.TEXT_DIM))
		var cancel := UIKit.button("Cancel match", UIKit.RED, 13, 32)
		cancel.pressed.connect(func() -> void:
			Battle.clear()
			notified.emit("Match cancelled.", UIKit.TEXT_DIM)
			_rebuild("battles"))
		card.add_child(cancel)
		_add_card(list, card)
		return

	_section(list, "MATCH TYPE")
	var modes := UIKit.hbox(6)
	for mode_id in ["solo", "tournament", "clan_war"]:
		var mid: String = mode_id
		var b := UIKit.button(Battle.mode_info(mid)["name"], UIKit.RED if mid == _battle_mode else UIKit.TEXT_DIM, 12, 30)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			_battle_mode = mid
			_rebuild("battles"))
		modes.add_child(b)
	list.add_child(modes)
	var info := Battle.mode_info(_battle_mode)
	var mcard := _card(Color(UIKit.RED.r, UIKit.RED.g, UIKit.RED.b, 0.45))
	mcard.add_child(UIKit.label(info["name"], 17, UIKit.TEXT))
	mcard.add_child(UIKit.wrapped(info["desc"], 12))
	mcard.add_child(UIKit.wrapped("Golden Rule: you only fight opponents of exactly your rank (%s). Any class can fight any class." % RankManager.rank_letter(), 11, UIKit.TEXT_DIM))
	var rew := UIKit.hbox(6)
	rew.add_child(UIKit.tag("WIN +%d RENOWN" % int(info["win_renown"]), UIKit.ACCENT2, 10))
	rew.add_child(UIKit.tag("+%d PTS" % int(info["win_points"]), UIKit.ACCENT, 10))
	mcard.add_child(rew)
	_add_card(list, mcard)

	if _battle_mode == "tournament":
		_section(list, "TOURNAMENT TIERS")
		var tiers := UIKit.hbox(6)
		for tier in RankManager.RANKS:
			var t: String = tier
			var ok := Battle.can_enter_tournament(t)
			var tb := UIKit.button(("Rank %s" % t) if ok else ("%s  locked" % t), UIKit.GREEN if ok else UIKit.TEXT_DIM, 11, 28)
			tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tb.disabled = not ok
			tiers.add_child(tb)
		list.add_child(tiers)
		list.add_child(UIKit.wrapped("You can only enter the tournament for your own tier. Eliminated fighters spectate until the match ends.", 11, UIKit.TEXT_DIM))

	if _battle_mode == "clan_war":
		_section(list, "%s  -  PICK UP TO 4 MEMBERS (YOU MAKE FIVE)" % str(BattleData.CLAN["name"]).to_upper())
		for m in BattleData.CLAN_MEMBERS:
			var name: String = m["name"]
			var eligible: bool = m["online"] and m["rank"] == RankManager.rank_letter()
			var picked := _battle_allies.has(name)
			var row := UIKit.hbox(8)
			var col := UIKit.vbox(0)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_child(UIKit.label(name, 14, UIKit.TEXT if eligible else UIKit.TEXT_DIM))
			var why := "%s  -  Rank %s  -  %s" % [m["class"], m["rank"], "online" if m["online"] else "offline"]
			if not eligible:
				why += "  (not at this tier)" if m["online"] else ""
			col.add_child(UIKit.label(why, 10, UIKit.TEXT_DIM))
			row.add_child(col)
			var pick := UIKit.button("Picked" if picked else "Pick", UIKit.GREEN if picked else UIKit.ACCENT, 11, 28)
			pick.custom_minimum_size = Vector2(76, 28)
			pick.disabled = not eligible or (not picked and _battle_allies.size() >= 4)
			pick.pressed.connect(func() -> void:
				if picked:
					_battle_allies.erase(name)
				else:
					_battle_allies.append(name)
				_rebuild("battles"))
			row.add_child(pick)
			list.add_child(row)
		list.add_child(UIKit.wrapped("Both clan leaders agree the tier, pick members who are online at that rank, and choose a map. Rival: %s." % BattleData.CLAN["rival"], 11, UIKit.TEXT_DIM))

	_section(list, "PREFERRED BATTLEFIELD")
	for mp in BattleData.MAPS:
		var mid: String = mp["id"]
		var chosen := _battle_map == mid
		var mc := _card(Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, 0.6) if chosen else Color(1, 1, 1, 0.08))
		var top := UIKit.hbox(8)
		top.add_child(UIKit.label(mp["name"], 15, UIKit.TEXT))
		top.add_child(UIKit.spacer())
		if chosen:
			top.add_child(UIKit.tag("PREFERRED", UIKit.ACCENT, 10))
		mc.add_child(top)
		mc.add_child(UIKit.wrapped(mp["desc"], 11))
		if not chosen:
			var pb := UIKit.button("Prefer this map", UIKit.ACCENT, 12, 28)
			pb.pressed.connect(func() -> void:
				_battle_map = mid
				_rebuild("battles"))
			mc.add_child(pb)
		_add_card(list, mc)
	list.add_child(UIKit.wrapped("If your opponent prefers a different map, the system picks one at random.", 11, UIKit.TEXT_DIM))

	var go := UIKit.button("Find match", UIKit.RED, 15, 40)
	go.pressed.connect(func() -> void:
		var m := Battle.setup_match(_battle_mode, _battle_map, _battle_allies)
		if not m.is_empty():
			notified.emit(m["message"], UIKit.GREEN)
			close()
		_rebuild("battles"))
	list.add_child(go)
	if not Battle.last_result.is_empty():
		var r := Battle.last_result
		var lc := _card()
		lc.add_child(UIKit.label("LAST MATCH", 11, UIKit.TEXT_DIM))
		lc.add_child(UIKit.label("%s on %s  -  %s" % [r["mode_name"], r["map_name"], "VICTORY" if r["won"] else "DEFEAT"], 14, UIKit.GREEN if r["won"] else UIKit.RED))
		lc.add_child(UIKit.label("+%d renown   +%d points" % [int(r["renown"]), int(r["points"])], 12, UIKit.TEXT_DIM))
		_add_card(list, lc)
