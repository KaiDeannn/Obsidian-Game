extends Control
class_name RadarMap
## Base class for the circular mini-maps. Renders the live 3D world top-down through a
## SubViewport (shared World3D, orthographic camera), masks it to a circle with a shader,
## and lets subclasses draw markers on an Overlay via _draw_overlay().
## Hierarchy (built in code): RadarMap(Control) -> SubViewport -> Camera3D ; TextureRect ; Overlay

@export var map_px := 220
@export var view_meters := 130.0
@export var camera_height := 140.0

var tracked: Node3D
var _viewport: SubViewport
var _cam: Camera3D
var _tex: TextureRect
var _overlay: Control


class Overlay extends Control:
	var map: RadarMap
	func _draw() -> void:
		if map:
			map._draw_overlay(self)


func _ready() -> void:
	custom_minimum_size = Vector2(map_px, map_px)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(map_px, map_px)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.positional_shadow_atlas_size = 0
	add_child(_viewport)

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = view_meters
	_cam.near = 1.0
	_cam.far = 600.0
	_cam.rotation_degrees = Vector3(-90, 0, 0)
	_cam.environment = _make_map_environment()
	_cam.current = true
	_viewport.add_child(_cam)

	_tex = TextureRect.new()
	_tex.texture = _viewport.get_texture()
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.material = _make_mask_material()
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tex)
	UIKit.full_rect(_tex)

	_overlay = Overlay.new()
	_overlay.map = self
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	UIKit.full_rect(_overlay)


func _process(_delta: float) -> void:
	if is_instance_valid(tracked):
		var p := tracked.global_position
		_cam.global_position = Vector3(p.x, p.y + camera_height, p.z)
	_overlay.queue_redraw()


func center() -> Vector2:
	return size * 0.5


func radius() -> float:
	return size.x * 0.5


func px_per_meter() -> float:
	return size.x / view_meters


## World position -> overlay pixel. clamp_to_edge pins far markers onto the ring.
func world_to_map(world: Vector3, clamp_to_edge := false) -> Vector2:
	if not is_instance_valid(tracked):
		return center()
	var t := tracked.global_position
	var d := Vector2(world.x - t.x, world.z - t.z) * px_per_meter()
	var r := radius() - 10.0
	if clamp_to_edge and d.length() > r:
		d = d.normalized() * r
	return center() + d


func is_within(world: Vector3) -> bool:
	var t := tracked.global_position
	return Vector2(world.x - t.x, world.z - t.z).length() * px_per_meter() < radius() - 6.0


## Forward (yaw) of a Node3D as a 2D map direction (north = up).
static func heading_2d(node: Node3D) -> Vector2:
	var f := -node.global_transform.basis.z
	return Vector2(f.x, f.z).normalized()


func draw_arrow(canvas: CanvasItem, at: Vector2, dir: Vector2, size_px: float, color: Color) -> void:
	var perp := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([
		at + dir * size_px,
		at - dir * size_px * 0.7 + perp * size_px * 0.6,
		at - dir * size_px * 0.3,
		at - dir * size_px * 0.7 - perp * size_px * 0.6,
	])
	canvas.draw_colored_polygon(pts, color)
	canvas.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.8), 1.5, true)


func draw_diamond(canvas: CanvasItem, at: Vector2, size_px: float, color: Color) -> void:
	var pts := PackedVector2Array([at + Vector2(0, -size_px), at + Vector2(size_px, 0), at + Vector2(0, size_px), at + Vector2(-size_px, 0)])
	canvas.draw_colored_polygon(pts, color)
	canvas.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.8), 1.5, true)


func draw_ring(canvas: CanvasItem, color: Color, width := 3.0) -> void:
	canvas.draw_arc(center(), radius() - 1.5, 0.0, TAU, 96, color, width, true)
	canvas.draw_arc(center(), radius() - 1.5 - width, 0.0, TAU, 96, Color(0, 0, 0, 0.6), 1.0, true)
	# North tick.
	canvas.draw_line(center() + Vector2(0, -radius() + 2), center() + Vector2(0, -radius() + 10), color, 2.0)
	canvas.draw_string(ThemeDB.fallback_font, center() + Vector2(-5, -radius() + 24), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)


## Subclasses override to draw markers.
func _draw_overlay(_canvas: CanvasItem) -> void:
	pass


func _make_map_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.065, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.95)
	env.ambient_light_energy = 1.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = false
	env.glow_enabled = false
	return env


func _make_mask_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d) * 2.0;
	vec4 c = texture(TEXTURE, UV);
	float a = 1.0 - smoothstep(0.97, 1.0, r);
	float vignette = 1.0 - smoothstep(0.75, 1.0, r) * 0.45;
	COLOR = vec4(c.rgb * vignette, c.a * a);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m
