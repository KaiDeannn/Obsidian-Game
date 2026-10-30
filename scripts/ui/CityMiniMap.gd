extends RadarMap
class_name CityMiniMap
## City mini-map: live top-down render + markers for player, vehicle, active objective,
## Spire gate and Heights properties. Carries the Speedometer readout whose colour is
## Green < 50 mph, Yellow 50-70 mph, Red > 70 mph.

var player: Node3D
var vehicle: Node3D
var objective := Vector3.ZERO
var has_objective := false

var _speed_label: Label
var _speed_mode: Label
var _mph := 0.0
var _driving := false
var _pulse := 0.0


func bind(p: Node3D, v: Node3D) -> void:
	player = p
	vehicle = v
	tracked = p


func _ready() -> void:
	super._ready()
	var strip := UIKit.panel(UIKit.PANEL_BG, 10, Color(1, 1, 1, 0.1), 8)
	strip.position = Vector2(0, map_px + 8)
	strip.custom_minimum_size = Vector2(map_px, 0)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	var row := UIKit.hbox(6)
	strip.add_child(row)
	_speed_mode = UIKit.label("ON FOOT", 12, UIKit.TEXT_DIM)
	_speed_mode.custom_minimum_size = Vector2(70, 0)
	_speed_mode.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_speed_mode)
	_speed_label = UIKit.label("0 MPH", 26, UIKit.GREEN, HORIZONTAL_ALIGNMENT_RIGHT)
	_speed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_speed_label)


func set_speed(mph: float, driving: bool) -> void:
	_mph = mph
	_driving = driving
	var color := UIKit.GREEN
	if mph > 70.0:
		color = UIKit.RED
	elif mph >= 50.0:
		color = UIKit.AMBER
	_speed_label.text = "%d MPH" % int(round(mph))
	_speed_label.add_theme_color_override("font_color", color)
	_speed_mode.text = "DRIVING" if driving else "ON FOOT"
	_speed_mode.add_theme_color_override("font_color", color if driving else UIKit.TEXT_DIM)
	# When driving, the map follows the car.
	tracked = vehicle if driving else player


func _process(delta: float) -> void:
	super._process(delta)
	_pulse += delta


func _draw_overlay(c: CanvasItem) -> void:
	if not is_instance_valid(tracked):
		return
	# Properties.
	for prop in CityData.PROPERTIES:
		var pos: Vector3 = prop["position"]
		if is_within(pos):
			var owned := GameState.owns_property(prop["id"])
			c.draw_rect(Rect2(world_to_map(pos) - Vector2(4, 4), Vector2(8, 8)), UIKit.GREEN if owned else UIKit.GOLD)
	# Spire gate (pinned to the ring when far).
	var gate_pt := world_to_map(CityData.GATE_POSITION, true)
	var gate_dir := (gate_pt - center()).normalized()
	if gate_dir.length() < 0.1:
		gate_dir = Vector2.UP
	draw_arrow(c, gate_pt, gate_dir, 7.0, UIKit.ACCENT2)
	# Every vehicle in the city (the valet's deliveries pulse cyan while en route).
	for v in get_tree().get_nodes_in_group("vehicles"):
		if not (v is Node3D) or (_driving and v == tracked):
			continue
		var vpos: Vector3 = (v as Node3D).global_position
		if not is_within(vpos):
			continue
		var vp := world_to_map(vpos)
		var en_route: bool = v.get("autopilot") == true
		if en_route:
			c.draw_circle(vp, 6.0 + sin(_pulse * 6.0) * 2.0, Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, 0.35))
		c.draw_rect(Rect2(vp - Vector2(5, 3), Vector2(10, 6)), UIKit.ACCENT if en_route else UIKit.AMBER)
	# Objective with pulse + edge pin.
	if has_objective:
		var op := world_to_map(objective, true)
		var pulse := 7.0 + sin(_pulse * 5.0) * 2.0
		c.draw_circle(op, pulse + 5.0, Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, 0.18))
		draw_diamond(c, op, pulse, UIKit.ACCENT)
	# Player arrow (centre).
	var heading := RadarMap.heading_2d(tracked)
	draw_arrow(c, center(), heading, 9.0, Color.WHITE)
	draw_ring(c, UIKit.ACCENT if not _driving else (UIKit.RED if _mph > 70.0 else (UIKit.AMBER if _mph >= 50.0 else UIKit.GREEN)))
