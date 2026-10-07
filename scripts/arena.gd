extends Node3D
## Flat, collision-safe procedural arenas. Map 0: Qamar Dunes; map 1: Wadi Highlands.
## Decorative geometry is instanced by mesh/material to keep mobile draw calls low.

var extent: float = 125.0

var _compact: bool = false
var _map_id: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _obstacles: Array[Rect2] = []
var _reserved: Array[Rect2] = []
var _materials: Dictionary = {}
var _batches: Dictionary = {}
var _meshes: Dictionary = {}


func build(map_id: int, compact: bool = false) -> void:
	# Call only after add_child(). A second build replaces this arena's children.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_map_id = posmod(map_id, 2)
	_compact = compact
	extent = 42.0 if compact else 125.0
	_rng.seed = 4417 + _map_id * 971 + int(compact) * 37
	_obstacles.clear()
	_reserved.clear()
	_materials.clear()
	_batches.clear()
	_meshes.clear()
	_make_palette()
	_make_meshes()
	# These broad open staging lanes protect the two four-player team spawns.
	var base_z: float = extent - 10.0
	_reserved.append(Rect2(Vector2(-14.0, base_z - 13.0), Vector2(28.0, 21.0)))
	_reserved.append(Rect2(Vector2(-14.0, -base_z - 8.0), Vector2(28.0, 21.0)))
	_reserved.append(Rect2(Vector2(-5.0, -5.0), Vector2(10.0, 10.0)))
	_make_environment()
	_box(Vector3(0.0, -0.6, 0.0), Vector3(extent * 2.0 + 12.0, 1.2,
		extent * 2.0 + 12.0), "ground", true, false)
	_make_terrain()
	_make_boundaries()
	if _map_id == 0:
		_build_dunes()
	else:
		_build_highlands()
	_flush_batches()


func spawn_points(count: int, teams: bool = false) -> Array[Vector3]:
	## All returned points are at y=1, clear of solid footprints and each other.
	## In team mode indices 0..3 are south; indices 4..7 are north.
	var result: Array[Vector3] = []
	if count <= 0:
		return result
	if teams:
		for index in range(count):
			var side: float = 1.0 if index % 8 < 4 else -1.0
			var slot: int = index % 4
			var row: int = int(index / 8)
			var point: Vector3 = Vector3((float(slot) - 1.5) * 7.0, 1.0,
				side * (extent - 10.0 - float(row) * 5.0))
			if _spawn_clear(point, result, 3.0):
				result.append(point)
			else:
				_append_safe_spawn(result, side)
		return result
	# An equal-area spiral fills the arena, instead of putting all 50 players on
	# the first outer ring. Rotate blocked candidates before using the grid fallback.
	var radius: float = extent - 12.0
	var golden_angle: float = PI * (3.0 - sqrt(5.0))
	for index in range(count):
		var spawn_radius: float = radius * sqrt((float(index) + 0.5) / float(count))
		for attempt in range(12):
			var angle: float = golden_angle * float(index) + float(attempt) * 0.71
			var point: Vector3 = Vector3(sin(angle) * spawn_radius, 1.0,
				cos(angle) * spawn_radius)
			if _spawn_clear(point, result, 6.0):
				result.append(point)
				break
	while result.size() < count:
		var previous_size: int = result.size()
		_append_safe_spawn(result)
		if result.size() == previous_size:
			push_warning("Arena has no further safe spawn slots; returning available points.")
			break
	return result


func _append_safe_spawn(points: Array[Vector3], side: float = 0.0) -> void:
	# Deterministic fallback scans only walkable space, never blindly uses origin.
	var step: float = 4.0
	var limit: float = extent - 5.0
	var z: float = -limit
	while z <= limit:
		var x: float = -limit
		while x <= limit:
			var point: Vector3 = Vector3(x, 1.0, z)
			if (side == 0.0 or z * side > extent * 0.35) \
					and Vector2(x, z).length() < extent - 4.0 \
					and _spawn_clear(point, points, 3.0):
				points.append(point)
				return
			x += step
		z += step


func _spawn_clear(point: Vector3, others: Array[Vector3], spacing: float) -> bool:
	if absf(point.x) > extent - 3.0 or absf(point.z) > extent - 3.0:
		return false
	var flat: Vector2 = Vector2(point.x, point.z)
	for obstacle in _obstacles:
		# Inclusive intersection also rejects a point exactly on a padded edge.
		if obstacle.grow(2.0).intersects(Rect2(flat, Vector2.ZERO), true):
			return false
	for other in others:
		if point.distance_squared_to(other) < spacing * spacing:
			return false
	return true


func _make_palette() -> void:
	var colors: Dictionary = {
		"ground": Color("d8b47a") if _map_id == 0 else Color("68855c"),
                "ground_alt": Color("c9a66d") if _map_id == 0 else Color("5f7d54"),
                "ground_light": Color("e2c18a") if _map_id == 0 else Color("789568"),
		"road": Color("e8ca91") if _map_id == 0 else Color("9c9a7b"),
		"wall": Color("c99760") if _map_id == 0 else Color("697b78"),
		"plaster": Color("f0d7ab"), "plaster_dark": Color("c48055"),
		"trim": Color("f6e8c8"), "dark": Color("343e43"),
		"wood": Color("775647"), "roof": Color("476a73"),
		"blue": Color("348f9b"), "orange": Color("df8c46"),
		"rock": Color("b18c68") if _map_id == 0 else Color("7d8986"),
		"rock_light": Color("d0ad7e") if _map_id == 0 else Color("a1aaa0"),
                "landmark": Color("8f6f55") if _map_id == 0 else Color("5b6968"),
		"leaf": Color("3b7059"), "leaf_light": Color("639466"),
		"water": Color("488f9a"), "sandbag": Color("b4ad83"),
	}
	for key in colors:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = colors[key]
		material.roughness = 0.95
		_materials[key] = material


func _make_meshes() -> void:
	var cube: BoxMesh = BoxMesh.new()
	cube.size = Vector3.ONE
	_meshes["box"] = cube
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 0.5
	cylinder.bottom_radius = 0.5
	cylinder.height = 1.0
	cylinder.radial_segments = 8
	_meshes["cylinder"] = cylinder
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 7
	_meshes["cone"] = cone
	var rock: SphereMesh = SphereMesh.new()
	rock.radius = 0.5
	rock.height = 1.0
	rock.radial_segments = 7
	rock.rings = 3
	_meshes["rock"] = rock


func _make_environment() -> void:
	var world: WorldEnvironment = WorldEnvironment.new()
	world.name = "ArenaEnvironment"
	var environment: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("6599be") if _map_id == 0 else Color("6196b0")
	sky_material.sky_horizon_color = Color("f2dbb0") if _map_id == 0 else Color("cfdfcf")
	sky_material.ground_bottom_color = Color("917756") if _map_id == 0 else Color("506850")
	sky_material.ground_horizon_color = sky_material.sky_horizon_color
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fff0d4") if _map_id == 0 else Color("d9e9f2")
	environment.ambient_light_energy = 0.65
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	world.environment = environment
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "AfternoonSun"
	sun.rotation_degrees = Vector3(-52.0, -32.0 if _map_id == 0 else 38.0, 0.0)
	sun.light_color = Color("ffe3b5") if _map_id == 0 else Color("fff2db")
	sun.light_energy = 1.15
	# No realtime shadow atlas, SSAO or fog: works with the mobile compatibility renderer.
	sun.shadow_enabled = false
	add_child(sun)


func _make_terrain() -> void:
	var grid_size: int = 18 if _compact else 42
	var cell_size: float = extent * 2.0 / float(grid_size)
	var half: float = extent

	for z in range(grid_size):
		for x in range(grid_size):
			var px: float = -half + (float(x) + 0.5) * cell_size
			var pz: float = -half + (float(z) + 0.5) * cell_size
			var height: float = 0.0

			if _map_id == 0:
				height = sin(px * 0.045) * 1.8 + cos(pz * 0.055) * 1.4
				height += sin((px + pz) * 0.025) * 1.1
			else:
				height = sin(px * 0.035) * 2.4 + cos(pz * 0.04) * 2.0
				height += sin((px - pz) * 0.022) * 1.8

			var road_distance: float = minf(absf(px), absf(pz))
			if road_distance < (4.5 if _map_id == 0 else 3.5):
				height *= 0.15

			var reserved := false
			for area in _reserved:
				if area.has_point(Vector2(px, pz)):
					reserved = true
					break
			if reserved:
				height *= 0.1

			var material_key: String = "ground"
			if road_distance >= (4.5 if _map_id == 0 else 3.5) and not reserved:
				var terrain_roll: float = _rng.randf()
				if terrain_roll < 0.16:
					material_key = "ground_alt"
				elif terrain_roll < 0.28:
					material_key = "ground_light"

			var scale_y: float = maxf(0.25, height + 1.5)
			_instance("box", Vector3(px, scale_y * 0.5 - 0.2, pz), Vector3(cell_size * 0.92, scale_y, cell_size * 0.92), material_key)

func _make_boundaries() -> void:
	var span: float = extent * 2.0 + 3.2
	for side in [-1.0, 1.0]:
		_box(Vector3(side * (extent + 0.8), 2.0, 0.0), Vector3(1.6, 4.0, span), "wall")
		_box(Vector3(0.0, 2.0, side * (extent + 0.8)), Vector3(span, 4.0, 1.6), "wall")
		# Distant scenery is outside the impenetrable play boundary.
		for index in range(7):
			var along: float = lerpf(-extent, extent, float(index) / 6.0)
			var height: float = _rng.randf_range(10.0, 23.0)
			_instance("rock", Vector3(along, 0.0, side * (extent + 19.0)),
				Vector3(43.0, height * 2.0, 32.0), "rock", _rng.randf_range(-1.0, 1.0))
			_instance("rock", Vector3(side * (extent + 22.0), 0.0, along),
				Vector3(32.0, height * 2.0, 43.0), "rock_light")


func _build_dunes() -> void:
	# A crossroads, shaded market, adobe compounds, tanks and delivery crates.
	_box(Vector3(0.0, 0.012, 0.0), Vector3(8.0, 0.02, extent * 2.0), "road", false)
	_box(Vector3(0.0, 0.014, 0.0), Vector3(extent * 2.0, 0.02, 8.0), "road", false)
	var grid: Array = [-24.0, 24.0] if _compact else [-84.0, -42.0, 42.0, 84.0]
	for x in grid:
		for z in grid:
			var center: Vector3 = Vector3(x, 0.0, z)
			var size: Vector3 = Vector3(_rng.randf_range(8.0, 11.0),
				_rng.randf_range(4.0, 6.2), _rng.randf_range(7.0, 10.0))
			_adobe_building(center, size)
			_market_stall(center + Vector3(-size.x * 0.65 - 3.0, 0.0, 1.0))
	for index in range(14 if _compact else 60):
		var point: Vector3 = _random_prop_position()
		var size: Vector3 = Vector3(_rng.randf_range(1.5, 3.0),
			_rng.randf_range(1.0, 1.7), _rng.randf_range(1.5, 2.4))
		if _footprint_available(point, Vector2(size.x, size.z), 2.4):
			_box(point + Vector3.UP * size.y * 0.5, size, "wood")
			_box(point + Vector3(0.0, size.y + 0.045, 0.0),
				Vector3(size.x + 0.08, 0.09, size.z + 0.08), "trim", false)
	_add_water_tank(Vector3(13.0, 0.0, -12.0))
	_rock_formation(Vector3(-48.0, 0.0, -52.0), 1.4)
	_rock_formation(Vector3(54.0, 0.0, 38.0), 1.1)
	_rock_formation(Vector3(-62.0, 0.0, 58.0), 0.9)
	_landmark_formation(Vector3(72.0, 0.0, -62.0), 1.8)


func _adobe_building(center: Vector3, size: Vector3) -> void:
	if not _footprint_available(center, Vector2(size.x + 2.0, size.z + 2.0), 3.0):
		return
	var wall_material: String = "plaster" if _rng.randf() > 0.3 else "plaster_dark"
	_box(center + Vector3.UP * size.y * 0.5, size, wall_material)
	_box(center + Vector3.UP * (size.y + 0.12), Vector3(size.x + 0.5, 0.24,
		size.z + 0.5), "trim", false)
	# Doors/windows are painted panels: buildings are intentionally solid cover.
	for side in [-1.0, 1.0]:
		_box(center + Vector3(0.0, 1.25, side * (size.z * 0.5 + 0.025)),
			Vector3(1.3, 2.5, 0.05), "blue", false)
		for window_x in [-0.3, 0.3]:
			_box(center + Vector3(size.x * window_x, 2.7, side * (size.z * 0.5 + 0.03)),
				Vector3(1.2, 1.0, 0.06), "dark", false)
	_box(center + Vector3(size.x * 0.2, size.y + 0.9, 0.0),
		Vector3(1.7, 1.6, 1.7), "blue", false)


func _market_stall(center: Vector3) -> void:
	if not _footprint_available(center, Vector2(4.6, 4.6), 2.0):
		return
	_box(center + Vector3(0.0, 0.65, 0.0), Vector3(3.5, 1.3, 2.0), "wood")
	for side in [-1.0, 1.0]:
		_box(center + Vector3(side * 1.9, 1.55, 0.0), Vector3(0.18, 3.1, 0.18), "wood")
	_box(center + Vector3.UP * 3.05, Vector3(4.4, 0.16, 3.9), "orange", false)
	_box(center + Vector3(0.0, 2.84, 1.95), Vector3(4.4, 0.45, 0.12), "trim", false)


func _add_water_tank(center: Vector3) -> void:
	if not _footprint_available(center, Vector2(5.0, 5.0), 3.0):
		return
	_box(center + Vector3.UP * 0.8, Vector3(4.0, 1.6, 4.0), "wall")
	_cylinder(center + Vector3.UP * 3.0, 1.7, 2.8, "blue")
	_instance("cone", center + Vector3.UP * 4.6, Vector3(3.6, 0.6, 3.6), "trim")


func _build_highlands() -> void:
	# Green valley outpost, slate cabins, evergreen clusters and low rock cover.
	_box(Vector3(0.0, 0.012, 0.0), Vector3(6.0, 0.02, extent * 2.0), "road", false)
	_box(Vector3(0.0, 0.015, 0.0), Vector3(extent * 2.0, 0.02, 6.0), "road", false)
	var grid: Array = [-23.0, 23.0] if _compact else [-78.0, -36.0, 36.0, 78.0]
	for x in grid:
		for z in grid:
			_outpost(Vector3(x, 0.0, z))
	for index in range(32 if _compact else 125):
		var point: Vector3 = _random_prop_position()
		if index % 3 == 0:
			var size: Vector3 = Vector3(_rng.randf_range(2.3, 4.0),
				_rng.randf_range(1.4, 2.6), _rng.randf_range(2.0, 3.4))
			if _footprint_available(point, Vector2(size.x, size.z), 2.0):
				# A faceted box rock keeps its collision identical to the visible cover.
				_box(point + Vector3.UP * size.y * 0.5, size, "rock")
				_box(point + Vector3.UP * (size.y + 0.09),
					Vector3(size.x * 0.84, 0.18, size.z * 0.84), "rock_light", false)
		elif _footprint_available(point, Vector2(5.0, 5.0), 2.0):
			_tree(point, _rng.randf_range(4.8, 7.2))
	# A blue, shallow painted cistern is visual only; the ground stays walkable.
	_box(Vector3(12.0, 0.024, -12.0), Vector3(7.0, 0.025, 5.0), "water", false)
	_rock_formation(Vector3(-52.0, 0.0, -48.0), 1.25)
	_rock_formation(Vector3(48.0, 0.0, 44.0), 1.05)
	_rock_formation(Vector3(-64.0, 0.0, 62.0), 0.85)
	_landmark_formation(Vector3(68.0, 0.0, -58.0), 1.7)
	for side in [-1.0, 1.0]:
		var center: Vector3 = Vector3(side * 12.0, 0.0, side * 9.0)
		if _footprint_available(center, Vector2(6.0, 1.2), 1.0):
			_box(center + Vector3.UP * 0.7, Vector3(6.0, 1.4, 1.2), "sandbag")


func _outpost(center: Vector3) -> void:
	if not _footprint_available(center, Vector2(10.0, 9.0), 3.0):
		return
	_box(center + Vector3.UP * 1.9, Vector3(8.0, 3.8, 7.0), "wood")
	_box(center + Vector3.UP * 3.92, Vector3(9.2, 0.24, 8.2), "roof", false)
	_box(center + Vector3.UP * 4.2, Vector3(6.6, 0.4, 6.0), "roof", false)
	for side in [-1.0, 1.0]:
		_box(center + Vector3(0.0, 1.25, side * 3.53), Vector3(1.4, 2.5, 0.06), "dark", false)
		for x in [-2.5, 2.5]:
			_box(center + Vector3(x, 2.0, side * 3.54), Vector3(1.2, 1.1, 0.08), "blue", false)
	_box(center + Vector3(-2.8, 5.3, 0.0), Vector3(0.09, 2.8, 0.09), "dark", false)
	_box(center + Vector3(-2.2, 6.25, 0.0), Vector3(1.2, 0.45, 0.08), "orange", false)


func _landmark_formation(center: Vector3, scale: float) -> void:
	var pieces: int = 4 if _compact else 7
	for index in range(pieces):
		var angle: float = (TAU / float(pieces)) * float(index) + _rng.randf_range(-0.25, 0.25)
		var distance: float = _rng.randf_range(1.0, 2.4) * scale
		var width: float = _rng.randf_range(1.6, 2.6) * scale
		var height: float = _rng.randf_range(2.8, 4.8) * scale
		var rock_center := center + Vector3(cos(angle) * distance, height * 0.5, sin(angle) * distance)
		_box(rock_center, Vector3(width, height, width * 0.82), "landmark")
		_instance("rock", rock_center + Vector3.UP * (height * 0.5 + 0.18), Vector3(width * 0.72, 0.7 * scale, width * 0.58), "rock_light")

func _rock_formation(center: Vector3, scale: float) -> void:
	var pieces: int = 3 if _compact else 5
	for index in range(pieces):
		var angle: float = _rng.randf_range(0.0, TAU)
		var distance: float = _rng.randf_range(0.2, 1.4) * scale
		var rock_scale: float = _rng.randf_range(0.7, 1.35) * scale
		var rock_height: float = _rng.randf_range(1.4, 2.8) * scale
		var rock_center := center + Vector3(cos(angle) * distance, rock_height * 0.5, sin(angle) * distance)
		_box(rock_center, Vector3(rock_scale * 1.8, rock_height, rock_scale * 1.5), "rock")
		_instance("rock", rock_center + Vector3.UP * (rock_height * 0.5 + 0.12), Vector3(rock_scale * 1.25, 0.5, rock_scale), "rock_light")

func _tree(center: Vector3, height: float) -> void:
	_cylinder(center + Vector3.UP * 1.1, 0.38, 2.2, "wood")
	_instance("cone", center + Vector3.UP * (height * 0.52),
		Vector3(4.6, height * 0.75, 4.6), "leaf")
	_instance("cone", center + Vector3.UP * (height * 0.77),
		Vector3(3.2, height * 0.52, 3.2), "leaf_light")
	# Reserve the low foliage too, so spawning never places a camera in a tree.
	_obstacles.append(Rect2(Vector2(center.x - 2.3, center.z - 2.3), Vector2(4.6, 4.6)))


func _random_prop_position() -> Vector3:
	var limit: float = extent - 8.0
	return Vector3(_rng.randf_range(-limit, limit), 0.0, _rng.randf_range(-limit, limit))


func _footprint_available(center: Vector3, size: Vector2, padding: float) -> bool:
	var footprint: Rect2 = Rect2(Vector2(center.x, center.z) - size * 0.5, size)
	if absf(center.x) + size.x * 0.5 > extent - 5.0 \
			or absf(center.z) + size.y * 0.5 > extent - 5.0:
		return false
	# Keep a navigable cross through both maps, even with random cover placement.
	if absf(center.x) < size.x * 0.5 + 4.5 or absf(center.z) < size.y * 0.5 + 4.5:
		return false
	for reserved in _reserved:
		if footprint.grow(padding).intersects(reserved):
			return false
	for obstacle in _obstacles:
		if footprint.grow(padding).intersects(obstacle):
			return false
	return true


func _box(center: Vector3, size: Vector3, material: String, solid: bool = true,
		track_obstacle: bool = true) -> void:
	_instance("box", center, size, material)
	if not solid:
		return
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	_add_collision(center, shape)
	if track_obstacle:
		_obstacles.append(Rect2(Vector2(center.x - size.x * 0.5, center.z - size.z * 0.5),
			Vector2(size.x, size.z)))


func _cylinder(center: Vector3, radius: float, height: float, material: String) -> void:
	_instance("cylinder", center, Vector3(radius * 2.0, height, radius * 2.0), material)
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	_add_collision(center, shape)
	_obstacles.append(Rect2(Vector2(center.x - radius, center.z - radius),
		Vector2(radius * 2.0, radius * 2.0)))


func _add_collision(center: Vector3, shape: Shape3D) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)


func _instance(kind: String, center: Vector3, size: Vector3, material: String,
		yaw: float = 0.0) -> void:
	var key: String = kind + ":" + material
	if not _batches.has(key):
		_batches[key] = []
	var basis: Basis = Basis(Vector3.UP, yaw).scaled(size)
	_batches[key].append(Transform3D(basis, center))


func _flush_batches() -> void:
	for key in _batches:
		var parts: PackedStringArray = String(key).split(":")
		var transforms: Array = _batches[key]
		var multimesh: MultiMesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _meshes[parts[0]]
		multimesh.instance_count = transforms.size()
		for index in range(transforms.size()):
			multimesh.set_instance_transform(index, transforms[index])
		var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
		instance.name = String(key).replace(":", "_")
		instance.multimesh = multimesh
		instance.material_override = _materials[parts[1]]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	_batches.clear()
