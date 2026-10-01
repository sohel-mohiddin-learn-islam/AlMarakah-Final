extends Control
## North-up, arena-scale map. Only the caller's allied positions are accepted;
## there is deliberately no enemy tracking, physics query, or scene-tree scan.
const MAP_BACKGROUND = Color(0.035, 0.075, 0.1, 0.92)
const ALLY_COLOR = Color("66e1b3")
const ZONE_COLOR = Color("66cfff")

var player_position: Vector3 = Vector3.ZERO
var player_yaw: float = 0.0
var zone_radius: float = 125.0
var arena_extent: float = 125.0
var allies: Array[Vector3] = []
var is_cs: bool = false
var panel_style: StyleBoxFlat

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(188, 212)
	panel_style = StyleBoxFlat.new()
	panel_style.bg_color = MAP_BACKGROUND
	panel_style.set_corner_radius_all(12)

func update_radar(at: Vector3, yaw: float, radius: float, extent: float, allied_positions: Array[Vector3], cs_mode: bool) -> void:
	player_position = at
	player_yaw = yaw
	arena_extent = maxf(1.0, extent)
	zone_radius = clampf(radius, 0.0, arena_extent)
	is_cs = cs_mode
	# Solo BR has no allies. Never turn a passed BR actor list into enemy dots.
	allies.clear()
	if is_cs:
		allies.assign(allied_positions)
	queue_redraw()

func _map_rect() -> Rect2:
	var side: float = maxf(1.0, minf(size.x - 28.0, size.y - 52.0))
	return Rect2(Vector2((size.x - side) * 0.5, 26), Vector2.ONE * side)

func _map_point(world_position: Vector3, bounds: Rect2) -> Vector2:
	var offset: Vector2 = Vector2(world_position.x, world_position.z) / arena_extent
	var point: Vector2 = bounds.get_center() + offset * bounds.size * 0.5
	return point.clamp(bounds.position + Vector2.ONE * 6.0, bounds.end - Vector2.ONE * 6.0)

func _draw() -> void:
	var bounds: Rect2 = _map_rect()
	var font: Font = ThemeDB.fallback_font
	draw_style_box(panel_style, Rect2(Vector2.ZERO, size))
	draw_string(font, Vector2(size.x * 0.5 - 5, 18), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_rect(bounds, Color(0.09, 0.16, 0.19, 0.95))
	# A fixed square represents the actual arena walls; -Z is north/up.
	draw_line(Vector2(bounds.get_center().x, bounds.position.y), Vector2(bounds.get_center().x, bounds.end.y), Color(1, 1, 1, 0.08))
	draw_line(Vector2(bounds.position.x, bounds.get_center().y), Vector2(bounds.end.x, bounds.get_center().y), Color(1, 1, 1, 0.08))
	if not is_cs and zone_radius > 0.0:
		var radius: float = bounds.size.x * 0.5 * zone_radius / arena_extent
		draw_circle(bounds.get_center(), radius, Color(0.2, 0.65, 0.9, 0.12))
		draw_arc(bounds.get_center(), radius, 0.0, TAU, 64, ZONE_COLOR, 1.6, true)
	draw_rect(bounds, Color(0.65, 0.76, 0.78, 0.9), false, 1.5)
	for ally in allies:
		var point: Vector2 = _map_point(ally, bounds)
		draw_circle(point, 4.5, Color(0.02, 0.07, 0.08))
		draw_circle(point, 3.0, ALLY_COLOR)
	var player_point: Vector2 = _map_point(player_position, bounds)
	var forward: Vector2 = Vector2(-sin(player_yaw), -cos(player_yaw))
	var right: Vector2 = Vector2(-forward.y, forward.x)
	var arrow = PackedVector2Array([player_point + forward * 7.0, player_point - forward * 4.0 + right * 4.5, player_point - forward * 4.0 - right * 4.5])
	draw_colored_polygon(arrow, Color.WHITE)
	arrow.append(arrow[0])
	draw_polyline(arrow, Color(0.02, 0.07, 0.08), 1.4, true)
	var legend_y: float = size.y - 10.0
	draw_string(font, Vector2(14, legend_y), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	draw_circle(Vector2(57, legend_y - 4), 3.0, ALLY_COLOR if is_cs else ZONE_COLOR)
	draw_string(font, Vector2(65, legend_y), "ALLIES ONLY" if is_cs else "SAFE ZONE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ALLY_COLOR if is_cs else ZONE_COLOR)
