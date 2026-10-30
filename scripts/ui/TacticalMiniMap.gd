extends RadarMap
class_name TacticalMiniMap
## Circular tactical map for The Spire Ruins: live top-down render, directional player
## arrow, and enemy markers that only appear while the player has line of sight to them.
## LOS = a physics ray from the player's eye to the enemy's chest, testing World geometry
## only; anything solid in between hides the dot.

@export var los_mask: int = Palette.LAYER_WORLD

var player: Node3D
var _spotted: Dictionary = {}    # enemy -> seconds since last seen (for fade-out)
var _pulse := 0.0


func bind_player(p: Node3D) -> void:
	player = p
	tracked = p


func _ready() -> void:
	map_px = 210
	view_meters = 96.0
	camera_height = 70.0
	super._ready()


func _process(delta: float) -> void:
	super._process(delta)
	_pulse += delta
	for k in _spotted.keys():
		_spotted[k] = _spotted[k] + delta


func has_line_of_sight(enemy: Node3D) -> bool:
	if not is_instance_valid(player):
		return false
	var from := player.global_position + Vector3(0, 1.6, 0)
	var to := enemy.global_position + Vector3(0, 1.2, 0)
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, los_mask)
	var hit := space.intersect_ray(q)
	return hit.is_empty()


func _draw_overlay(c: CanvasItem) -> void:
	if not is_instance_valid(tracked):
		return
	# Range rings.
	for f in [0.33, 0.66]:
		c.draw_arc(center(), radius() * f, 0.0, TAU, 64, Color(1, 1, 1, 0.08), 1.0, true)
	c.draw_line(center() + Vector2(-radius(), 0), center() + Vector2(radius(), 0), Color(1, 1, 1, 0.06), 1.0)
	c.draw_line(center() + Vector2(0, -radius()), center() + Vector2(0, radius()), Color(1, 1, 1, 0.06), 1.0)
	# Spire centre marker.
	if is_within(Vector3.ZERO):
		draw_diamond(c, world_to_map(Vector3.ZERO), 5.0, UIKit.ACCENT2)
	# Enemies: visible only with line of sight; brief fade for ones that just broke LOS.
	var visible_count := 0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not (enemy is Node3D) or enemy.get("alive") == false:
			_spotted.erase(enemy)
			continue
		if not is_within(enemy.global_position):
			continue
		var seen := has_line_of_sight(enemy)
		if seen:
			_spotted[enemy] = 0.0
		var since: float = _spotted.get(enemy, 99.0)
		if since > 0.6:
			continue
		var alpha := 1.0 - since / 0.6
		var pt := world_to_map(enemy.global_position)
		var is_hunter: bool = enemy.get("kind") == TrainingDummy.Kind.HUNTER
		var col := UIKit.RED if is_hunter else UIKit.AMBER
		col.a = alpha
		if seen:
			visible_count += 1
			c.draw_circle(pt, 7.5 + sin(_pulse * 6.0) * 1.0, Color(col.r, col.g, col.b, 0.22 * alpha))
		c.draw_circle(pt, 4.5, col)
		if is_hunter:
			draw_arrow(c, pt, RadarMap.heading_2d(enemy), 6.0, col)
	# Player.
	draw_arrow(c, center(), RadarMap.heading_2d(tracked), 9.0, Color.WHITE)
	draw_ring(c, UIKit.RED if visible_count > 0 else UIKit.ACCENT)
	c.draw_string(ThemeDB.fallback_font, center() + Vector2(-radius() + 10, radius() - 8), "%d m" % int(view_meters * 0.5), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIKit.TEXT_DIM)
	c.draw_string(ThemeDB.fallback_font, center() + Vector2(radius() - 64, radius() - 8), "LOS %d" % visible_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIKit.RED if visible_count > 0 else UIKit.TEXT_DIM)
