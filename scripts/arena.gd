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

	_map_id = clampi(map_id, 0, 2)
	_compact = compact
	extent = 42.0 if compact else (960.0 if _map_id == 2 else 125.0)
	_rng.seed = 4417 + _map_id * 971 + int(compact) * 37
	_obstacles.clear()
	_reserved.clear()
	_materials.clear()
	_batches.clear()
	_meshes.clear()

	_make_palette()
	_make_meshes()

	# Keep the existing team staging reservations for both maps.
	var base_z: float = extent - 10.0
	_reserved.append(Rect2(Vector2(-14.0, base_z - 13.0), Vector2(28.0, 21.0)))
	_reserved.append(Rect2(Vector2(-14.0, -base_z - 8.0), Vector2(28.0, 21.0)))
	_reserved.append(Rect2(Vector2(-5.0, -5.0), Vector2(10.0, 10.0)))

	_make_environment()

	# Map 1 uses the real TerraForge world. Map 0 remains Qamar Dunes.
	if _map_id == 1 and _build_terraforge_world():
		_build_almarakah()
		_flush_batches()
		return

	# Existing procedural terrain remains the fallback if the GLB cannot load.
	_make_terrain()

	var fallback_shape := BoxShape3D.new()
	fallback_shape.size = Vector3(extent * 2.0 + 12.0, 1.2, extent * 2.0 + 12.0)
	var fallback_body := StaticBody3D.new()
	fallback_body.name = "FallbackGroundCollision"
	fallback_body.position = Vector3(0.0, -8.0, 0.0)
	fallback_body.collision_layer = 1
	fallback_body.collision_mask = 0

	var fallback_collider := CollisionShape3D.new()
	fallback_collider.shape = fallback_shape
	fallback_body.add_child(fallback_collider)
	add_child(fallback_body)

	_make_boundaries()

	if _map_id == 0:
		_build_dunes()
	elif _map_id == 2:
		_build_wasteland()
	else:
		_build_almarakah()

	_flush_batches()


func _build_terraforge_world() -> bool:
	var packed_world := load("res://assets/terraforge_world.glb") as PackedScene
	if packed_world == null:
		push_error("TerraForge world failed to load as a PackedScene.")
		return false

	var terraforge := packed_world.instantiate() as Node3D
	if terraforge == null:
		push_error("TerraForge scene root is not Node3D.")
		return false

	terraforge.name = "TerraForgeWorld"

	# GLB horizontal bounds are approximately 100 x 100 units.
	# Preserve terrain height while fitting the selected arena dimensions.
	var horizontal_scale: float = 0.84 if _compact else 2.5
	terraforge.scale = Vector3(horizontal_scale, 1.0, horizontal_scale)
	add_child(terraforge)

	_add_terraforge_collisions(terraforge)
	_add_terraforge_boundaries()

	print("TERRAFORGE MAP: loaded; compact=", _compact,
		" horizontal_scale=", horizontal_scale)
	return true


func _add_terraforge_collisions(world_root: Node) -> void:
	# Only give substantial X/Z meshes collision. This deliberately skips
	# the zero-depth mesh in the GLB, which is not a ground surface.
	var pending: Array[Node] = [world_root]
	var collision_meshes: int = 0

	while not pending.is_empty():
		var current: Node = pending.pop_back()

		for child in current.get_children():
			pending.append(child)

		if not (current is MeshInstance3D):
			continue

		var mesh_instance := current as MeshInstance3D
		if mesh_instance.mesh == null:
			continue

		var bounds: AABB = mesh_instance.mesh.get_aabb()
		if bounds.size.x < 10.0 or bounds.size.z < 10.0:
			continue
		if mesh_instance.mesh.get_surface_count() == 0:
			continue

		mesh_instance.create_trimesh_collision()
		collision_meshes += 1

		for collision_child in mesh_instance.get_children():
			if collision_child is StaticBody3D:
				collision_child.collision_layer = 1
				collision_child.collision_mask = 0

	if collision_meshes == 0:
		push_error("TerraForge imported, but no solid terrain meshes qualified for collision.")
	else:
		print("TERRAFORGE COLLISION: solid mesh count=", collision_meshes)


func _add_terraforge_boundaries() -> void:
	# Invisible safety boundaries keep players inside the playable world.
	var span: float = extent * 2.0 + 3.2
	for side in [-1.0, 1.0]:
		_add_terraforge_boundary_box(
			Vector3(side * (extent + 0.8), 4.0, 0.0),
			Vector3(1.6, 8.0, span)
		)
		_add_terraforge_boundary_box(
			Vector3(0.0, 4.0, side * (extent + 0.8)),
			Vector3(span, 8.0, 1.6)
		)


func _add_terraforge_boundary_box(at: Vector3, dimensions: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "TerraForgeBoundary"
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0

	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	body.add_child(collider)
	add_child(body)


func _spawn_ground_y(px: float, pz: float) -> float:
	if _map_id == 1:
		# TerraForge's highest terrain vertices are approximately Y=14.
		return 17.0

	var height: float
	if _map_id == 2:
		height = sin(px * 0.052) * 1.7 + cos(pz * 0.047) * 1.5
		height += sin((px + pz) * 0.031) * 1.0
		height *= 0.38
	else:
		height = sin(px * 0.045) * 1.8 + cos(pz * 0.055) * 1.4
		height += sin((px + pz) * 0.025) * 1.1
		height *= 0.45

	var reach: float = 42.0 if _compact else 84.0
	var offset: float = 24.0 if _compact else 42.0
	var path_length: float = reach + offset
	var path_width: float = (3.2 if _compact else 5.5) + 1.2
	var flat: bool = minf(absf(px), absf(pz)) < (4.8 if _map_id == 0 else 3.8)

	if absf(absf(pz) - offset) < path_width and absf(px) < path_length * 0.5 + path_width:
		flat = true
	if absf(absf(px) - offset) < path_width and absf(pz) < path_length * 0.5 + path_width:
		flat = true

	for area in _reserved:
		if area.has_point(Vector2(px, pz)):
			flat = true
			break

	if _map_id == 0:
		if absf(px) < 19.0 and absf(pz) < 19.0:
			flat = true
	else:
		var capital_x: float = extent * (0.66 if _compact else 0.42)
		var capital_z: float = -extent * 0.42
		var capital_half: float = 10.0 if _compact else 25.0
		if absf(px - capital_x) < capital_half + 8.0 and absf(pz - capital_z) < capital_half + 8.0:
			flat = true
		var gate_z: float = capital_z - capital_half
		if absf(pz - gate_z) < 4.5 and px > -5.0 and px < capital_x + 5.0:
			flat = true
		if absf(px - capital_x) < 4.5 and pz > gate_z - 4.5 and pz < 4.5:
			flat = true

	return (0.0 if flat else height) + 0.35


func spawn_points(count: int, teams: bool = false) -> Array[Vector3]:
	## All returned points are terrain-adjusted and clear of solid footprints and each other.
	## In team mode indices 0..3 are south; indices 4..7 are north.
	var result: Array[Vector3] = []
	if count <= 0:
		return result
	if teams:
		for index in range(count):
			var side: float = 1.0 if index % 8 < 4 else -1.0
			var slot: int = index % 4
			var row: int = int(index / 8)
			var point: Vector3 = Vector3((float(slot) - 1.5) * 7.0, _spawn_ground_y((float(slot) - 1.5) * 7.0, side * (extent - 10.0 - float(row) * 5.0)),
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
			var point: Vector3 = Vector3(sin(angle) * spawn_radius, _spawn_ground_y(sin(angle) * spawn_radius, cos(angle) * spawn_radius),
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
			var point: Vector3 = Vector3(x, _spawn_ground_y(x, z), z)
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
		"ground": Color("b99a70") if _map_id == 2 else (Color("d8b47a") if _map_id == 0 else Color("68855c")),
		"ground_alt": Color("a98b64") if _map_id == 2 else (Color("c9a66d") if _map_id == 0 else Color("5f7d54")),
		"ground_light": Color("d0b184") if _map_id == 2 else (Color("e2c18a") if _map_id == 0 else Color("789568")),
		"road": Color("b8a080") if _map_id == 2 else (Color("e8ca91") if _map_id == 0 else Color("9c9a7b")),
		"wall": Color("786b5b") if _map_id == 2 else (Color("c99760") if _map_id == 0 else Color("697b78")),
		"plaster": Color("f0d7ab"), "plaster_dark": Color("c48055"),
		"trim": Color("f6e8c8"), "dark": Color("343e43"),
		"wood": Color("775647"), "roof": Color("476a73"),
		"blue": Color("348f9b"), "orange": Color("df8c46"),
		"rock": Color("8d7b68") if _map_id == 2 else (Color("b18c68") if _map_id == 0 else Color("7d8986")),
		"rock_light": Color("b3a087") if _map_id == 2 else (Color("d0ad7e") if _map_id == 0 else Color("a1aaa0")),
		"landmark": Color("65584b") if _map_id == 2 else (Color("8f6f55") if _map_id == 0 else Color("5b6968")),
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
	sky_material.sky_top_color = Color("b8a58d") if _map_id == 2 else (Color("6599be") if _map_id == 0 else Color("6196b0"))
	sky_material.sky_horizon_color = Color("e1c6a0") if _map_id == 2 else (Color("f2dbb0") if _map_id == 0 else Color("cfdfcf"))
	sky_material.ground_bottom_color = Color("75604b") if _map_id == 2 else (Color("917756") if _map_id == 0 else Color("506850"))
	sky_material.ground_horizon_color = sky_material.sky_horizon_color
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e5cba6") if _map_id == 2 else (Color("fff0d4") if _map_id == 0 else Color("d9e9f2"))
	environment.ambient_light_energy = 0.64 if _map_id == 2 else (0.58 if _map_id == 0 else 0.70)
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	world.environment = environment
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "AfternoonSun"
	sun.rotation_degrees = Vector3(-52.0, -18.0 if _map_id == 2 else (-32.0 if _map_id == 0 else 38.0), 0.0)
	sun.light_color = Color("f2d2a3") if _map_id == 2 else (Color("ffe3b5") if _map_id == 0 else Color("fff2db"))
	sun.light_energy = 1.16 if _map_id == 2 else (1.22 if _map_id == 0 else 1.08)
	# No realtime shadow atlas, SSAO or fog: works with the mobile compatibility renderer.
	sun.shadow_enabled = false
	add_child(sun)


func _make_terrain() -> void:
	# A continuous, low-poly terrain surface for mobile performance.
	var grid_size: int = 36 if _compact else (192 if _map_id == 2 else 84)
	var cell_size: float = extent * 2.0 / float(grid_size)
	var capital_x: float = extent * (0.66 if _compact else 0.42)
	var capital_z: float = -extent * 0.42
	var capital_half: float = 10.0 if _compact else 25.0
	var reach: float = 42.0 if _compact else 84.0
	var offset: float = 24.0 if _compact else 42.0
	var path_length: float = reach + offset
	var path_width: float = (3.2 if _compact else 5.5) + 1.2
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var wasteland_outpost_centers: Array[Vector2] = []
	if _map_id == 2 and not _compact:
		wasteland_outpost_centers.append(Vector2(-610.0, -570.0))
		wasteland_outpost_centers.append(Vector2(610.0, -570.0))
		wasteland_outpost_centers.append(Vector2(-610.0, 570.0))
		wasteland_outpost_centers.append(Vector2(610.0, 570.0))
		wasteland_outpost_centers.append(Vector2(-160.0, -700.0))
		wasteland_outpost_centers.append(Vector2(160.0, 700.0))
		wasteland_outpost_centers.append(Vector2(-720.0, 80.0))
		wasteland_outpost_centers.append(Vector2(720.0, -80.0))

	# Shared grid vertices prevent gaps between terrain cells.
	for z in range(grid_size + 1):
		for x in range(grid_size + 1):
			var px: float = -extent + float(x) * cell_size
			var pz: float = -extent + float(z) * cell_size
			var height: float

			if _map_id == 0:
				height = sin(px * 0.045) * 1.8 + cos(pz * 0.055) * 1.4
				height += sin((px + pz) * 0.025) * 1.1
				height *= 0.45
			elif _map_id == 2:
				# Broad, wind-worn ridges for the industrial wasteland.
				height = sin(px * 0.052) * 1.7 + cos(pz * 0.047) * 1.5
				height += sin((px + pz) * 0.031) * 1.0
				height *= 0.38
			else:
				height = sin(px * 0.035) * 2.4 + cos(pz * 0.04) * 2.0
				height += sin((px - pz) * 0.022) * 1.8
				height *= 0.32

			var flat: bool = false

			# Main crossing roads remain level.
			if minf(absf(px), absf(pz)) < (4.8 if _map_id == 0 else 3.8):
				flat = true

			# Keep the offset secondary roads level.
			if absf(absf(pz) - offset) < path_width and absf(px) < path_length * 0.5 + path_width:
				flat = true
			if absf(absf(px) - offset) < path_width and absf(pz) < path_length * 0.5 + path_width:
				flat = true

			# Preserve spawn staging lanes and the central spawn area.
			for area in _reserved:
				if area.has_point(Vector2(px, pz)):
					flat = true
					break

			if _map_id == 0:
				# Keep the central desert road and settlement level.
				if absf(px) < 19.0 and absf(pz) < 19.0:
					flat = true
			else:
				# Level fortress foundations and its surrounding courtyard.
				if absf(px - capital_x) < capital_half + 8.0 and absf(pz - capital_z) < capital_half + 8.0:
					flat = true

				# Level the two road sections leading to the capital gate.
				var gate_z: float = capital_z - capital_half
				if absf(pz - gate_z) < 4.5 and px > -5.0 and px < capital_x + 5.0:
					flat = true
				if absf(px - capital_x) < 4.5 and pz > gate_z - 4.5 and pz < 4.5:
					flat = true


			if _map_id == 2 and not _compact:
				for center in wasteland_outpost_centers:
					if absf(px - center.x) < 42.0 and absf(pz - center.y) < 38.0:
						flat = true
						# Flatten the horizontal road leading toward each outpost.
						if absf(pz - center.y) < 10.1 and px >= minf(0.0, center.x) - 5.0 and px <= maxf(0.0, center.x) + 5.0:
							flat = true
						# Flatten the vertical road leading toward each outpost.
						if absf(px - center.x) < 10.1 and pz >= minf(0.0, center.y) - 5.0 and pz <= maxf(0.0, center.y) + 5.0:
							flat = true

			if flat:
				height = 0.0

			vertices.append(Vector3(px, height, pz))
			uvs.append(Vector2(float(x) / float(grid_size), float(z) / float(grid_size)))

	# Build upward-facing triangles from the shared grid.
	for z in range(grid_size):
		for x in range(grid_size):
			var a: int = z * (grid_size + 1) + x
			var b: int = a + 1
			var c: int = a + grid_size + 1
			var d: int = c + 1
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var raw_terrain_mesh := ArrayMesh.new()
	raw_terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Generate smooth vertex normals for consistent terrain lighting.
	var normal_builder := SurfaceTool.new()
	normal_builder.create_from(raw_terrain_mesh, 0)
	normal_builder.generate_normals()
	var terrain_mesh: ArrayMesh = normal_builder.commit()
	terrain_mesh.surface_set_material(0, _materials["ground"])
	terrain_mesh.surface_set_name(0, "Terrain")

	var terrain_instance := MeshInstance3D.new()
	terrain_instance.name = "ContinuousTerrain"
	terrain_instance.mesh = terrain_mesh
	terrain_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(terrain_instance)

	# Use the exact same mesh for collision so the surface and ground agree.
	var terrain_body := StaticBody3D.new()
	terrain_body.name = "TerrainCollision"
	terrain_body.collision_layer = 1
	terrain_body.collision_mask = 0
	var terrain_collider := CollisionShape3D.new()
	terrain_collider.name = "TerrainCollisionShape"
	var terrain_shape: ConcavePolygonShape3D = raw_terrain_mesh.create_trimesh_shape()
	terrain_shape.backface_collision = true
	terrain_collider.shape = terrain_shape
	terrain_body.add_child(terrain_collider)
	add_child(terrain_body)

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
	_secondary_paths(4.0 if _compact else 7.0)
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
	for scrub_index in range(8 if _compact else 28):
		var scrub_point: Vector3 = _random_prop_position()
		if _footprint_available(scrub_point, Vector2(3.2, 3.2), 1.5):
			_vegetation_cluster(scrub_point, _rng.randf_range(0.8, 1.35))
	_add_water_tank(Vector3(13.0, 0.0, -12.0))
	_rock_formation(Vector3(-48.0, 0.0, -52.0), 1.4)
	_rock_formation(Vector3(54.0, 0.0, 38.0), 1.1)
	_rock_formation(Vector3(-62.0, 0.0, 58.0), 0.9)
	_landmark_formation(Vector3(72.0, 0.0, -62.0), 1.8)


func _secondary_paths(width: float) -> void:
	var reach: float = 42.0 if _compact else 84.0
	var offset: float = 24.0 if _compact else 42.0
	var length: float = reach + offset
	var edge_width: float = width + 0.9
	for side in [-1.0, 1.0]:
		_box(Vector3(side * reach * 0.5, 0.012, side * offset), Vector3(length, 0.018, edge_width), "ground_alt", false)
		_box(Vector3(side * offset, 0.012, side * reach * 0.5), Vector3(edge_width, 0.018, length), "ground_alt", false)
		_box(Vector3(side * reach * 0.5, 0.013, -side * offset), Vector3(length, 0.018, edge_width), "ground_alt", false)
		_box(Vector3(-side * offset, 0.013, side * reach * 0.5), Vector3(edge_width, 0.018, length), "ground_alt", false)
		_box(Vector3(side * reach * 0.5, 0.020, side * offset), Vector3(length, 0.035, width), "road", false)
		_box(Vector3(side * offset, 0.020, side * reach * 0.5), Vector3(width, 0.035, length), "road", false)
		_box(Vector3(side * reach * 0.5, 0.021, -side * offset), Vector3(length, 0.035, width), "road", false)
		_box(Vector3(-side * offset, 0.021, side * reach * 0.5), Vector3(width, 0.035, length), "road", false)

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

	# CAPITAL_FACADE_DETAILS_V1
	# Decorative facade bands; these do not add collision shapes.
	var facade_z: float = center.z - size.z * 0.5 - 0.06
	_box(Vector3(center.x, 0.32, facade_z),
		Vector3(size.x * 0.88, 0.14, 0.08), "trim", false)
	_box(Vector3(center.x, size.y - 0.32, facade_z),
		Vector3(size.x * 0.88, 0.14, 0.08), "trim", false)
	for facade_side in [-1.0, 1.0]:
		_box(Vector3(center.x + facade_side * size.x * 0.38,
			size.y * 0.5, facade_z),
			Vector3(0.14, size.y * 0.78, 0.08), "plaster_dark", false)


func _market_stall(center: Vector3) -> void:
	if not _footprint_available(center, Vector2(4.6, 4.6), 2.0):
		return
	_box(center + Vector3(0.0, 0.65, 0.0), Vector3(3.5, 1.3, 2.0), "wood")
	for side in [-1.0, 1.0]:
		_box(center + Vector3(side * 1.9, 1.55, 0.0), Vector3(0.18, 3.1, 0.18), "wood")
	_box(center + Vector3.UP * 3.05, Vector3(4.4, 0.16, 3.9), "orange", false)
	_box(center + Vector3(0.0, 2.84, 1.95), Vector3(4.4, 0.45, 0.12), "trim", false)

	# MARKET_DISPLAY_DETAILS_V1
	# Decorative counter edging and stall fascia; no new collisions.
	_box(center + Vector3(0.0, 2.72, -1.99),
		Vector3(3.9, 0.18, 0.10), "plaster_dark", false)
	_box(center + Vector3(0.0, 0.18, -1.06),
		Vector3(3.65, 0.12, 0.10), "trim", false)
	for display_side in [-1.0, 1.0]:
		_box(center + Vector3(display_side * 1.72, 2.1, -0.92),
			Vector3(0.10, 1.7, 0.10), "trim", false)


func _add_water_tank(center: Vector3) -> void:
	if not _footprint_available(center, Vector2(5.0, 5.0), 3.0):
		return
	_box(center + Vector3.UP * 0.8, Vector3(4.0, 1.6, 4.0), "wall")
	_cylinder(center + Vector3.UP * 3.0, 1.7, 2.8, "blue")
	_instance("cone", center + Vector3.UP * 4.6, Vector3(3.6, 0.6, 3.6), "trim")




func _build_wasteland() -> void:
	# Industrial desert map. Keep all dimensions inside the selected arena,
	# including the smaller Clash Squad layout.
	var scale_factor: float = 0.32 if _compact else 1.0
	var cx: float = extent * (0.66 if _compact else 0.42)
	var cz: float = -extent * 0.42
	var half: float = 15.0 * scale_factor
	var wall_height: float = 3.2 * scale_factor
	var wall_thickness: float = 1.0 * scale_factor
	var shed_size: Vector3 = Vector3(7.0, 4.0, 6.0) * scale_factor

	# Broad dusty approach roads.
	_box(Vector3(0.0, -0.12, 0.0),
		Vector3(5.0 * scale_factor, 0.24, extent * 1.65),
		"road", false, false)
	_box(Vector3(0.0, -0.10, 0.0),
		Vector3(extent * 1.65, 0.20, 4.0 * scale_factor),
		"road", false, false)

	# A fortified industrial compound with an open front entrance.
	_box(Vector3(cx, wall_height * 0.5, cz - half),
		Vector3(half * 2.0, wall_height, wall_thickness),
		"wall")
	_box(Vector3(cx - half, wall_height * 0.5, cz),
		Vector3(wall_thickness, wall_height, half * 2.0),
		"wall")
	_box(Vector3(cx + half, wall_height * 0.5, cz),
		Vector3(wall_thickness, wall_height, half * 2.0),
		"wall")
	_box(Vector3(cx - half * 0.55, wall_height * 0.5, cz + half),
		Vector3(half * 0.9, wall_height, wall_thickness),
		"wall")
	_box(Vector3(cx + half * 0.55, wall_height * 0.5, cz + half),
		Vector3(half * 0.9, wall_height, wall_thickness),
		"wall")

	# Four low industrial sheds with space between them for combat.
	for side_x in [-1.0, 1.0]:
		for side_z in [-1.0, 1.0]:
			var p := Vector3(
				cx + side_x * half * 0.48,
				0.0,
				cz + side_z * half * 0.43
			)
			_box(p + Vector3(0.0, shed_size.y * 0.5, 0.0),
				shed_size, "dark")
			_box(p + Vector3(0.0, shed_size.y + 0.12 * scale_factor, 0.0),
				Vector3(shed_size.x + 0.5 * scale_factor,
					0.24 * scale_factor,
					shed_size.z + 0.5 * scale_factor),
				"roof", false, false)

	# Scattered cover and rocky landmarks outside the compound.
	for i in range(8):
		var angle: float = TAU * float(i) / 8.0
		var radius: float = extent * 0.48
		var px: float = cos(angle) * radius
		var pz: float = sin(angle) * radius
		_box(Vector3(px, 0.55 * scale_factor, pz),
			Vector3(2.4, 1.1, 1.5) * scale_factor,
			"sandbag")

	for i in range(5):
		var angle: float = TAU * float(i) / 5.0 + 0.3
		var radius: float = extent * 0.66
		_rock_formation(
			Vector3(cos(angle) * radius, 0.0, sin(angle) * radius),
			0.65 * scale_factor
		)

	_build_wasteland_outposts()
	print("WASTELAND MAP: procedural industrial desert built; compact=", _compact)


func _build_wasteland_outposts() -> void:
	# Preserve the existing compact Clash Squad layout.
	if _compact:
		return

	# Eight distributed settlement and industrial locations.
	var centers: Array[Vector2] = [
		Vector2(-610.0, -570.0),
		Vector2(610.0, -570.0),
		Vector2(-610.0, 570.0),
		Vector2(610.0, 570.0),
		Vector2(-160.0, -700.0),
		Vector2(160.0, 700.0),
		Vector2(-720.0, 80.0),
		Vector2(720.0, -80.0)
	]
	var offsets: Array[Vector2] = [
		Vector2(-19.0, -16.0),
		Vector2(0.0, -19.0),
		Vector2(19.0, -16.0),
		Vector2(-19.0, 16.0),
		Vector2(0.0, 19.0),
		Vector2(19.0, 16.0)
	]

	for i in range(centers.size()):
		var c: Vector2 = centers[i]
		var road_x: float = absf(c.x) - 10.0
		var road_z: float = absf(c.y) - 10.0

		if road_x > 0.0:
			_box(
				Vector3(signf(c.x) * road_x * 0.5, 0.018, c.y),
				Vector3(road_x, 0.035, 6.5),
				"road", false, false
			)
		if road_z > 0.0:
			_box(
				Vector3(c.x, 0.019, signf(c.y) * road_z * 0.5),
				Vector3(6.5, 0.035, road_z),
				"road", false, false
			)

		if i % 2 == 0:
			_adobe_building(
				Vector3(c.x, 0.0, c.y),
				Vector3(14.0, 5.5, 12.0)
			)
		else:
			_add_water_tank(Vector3(c.x, 0.0, c.y + 31.0))

		for j in range(offsets.size()):
			var o: Vector2 = offsets[j]
			var p := Vector3(c.x + o.x, 0.0, c.y + o.y)
			var size := Vector3(
				_rng.randf_range(8.0, 11.0),
				_rng.randf_range(4.0, 5.8),
				_rng.randf_range(7.0, 10.0)
			)
			_adobe_building(p, size)

	# Landmarks in the outer wilderness, away from the central combat lanes.
	for i in range(12):
		var angle: float = TAU * float(i) / 12.0 + 0.17
		var radius: float = extent * 0.80
		_rock_formation(
			Vector3(cos(angle) * radius, 0.0, sin(angle) * radius),
			1.05
		)


func _build_almarakah() -> void:
	# Map 1: Heartlands, the fortified capital, and the outer wilderness.
	_secondary_paths(3.0 if _compact else 5.2)

	# The capital sits away from the protected central spawn area.
	var capital := Vector3(extent * (0.66 if _compact else 0.42), 0.0, -extent * 0.42)
	var half_size: float = 10.0 if _compact else 25.0
	var wall_height: float = 4.2 if _compact else 6.0
	var wall_thickness: float = 1.4 if _compact else 2.0
	var road_width: float = 4.5 if _compact else 7.0

	# L-shaped roads lead from the Heartlands through the northern gate.
	var gate_z: float = capital.z - half_size
	_box(Vector3(capital.x * 0.5, 0.025, gate_z),
			Vector3(absf(capital.x) + road_width, 0.035, road_width),
			"road", false)
	_box(Vector3(capital.x, 0.025, gate_z * 0.5),
			Vector3(road_width, 0.035, absf(gate_z) + road_width),
			"road", false)

	# Fortified perimeter with an open central northern gate.
	for side in [-1.0, 1.0]:
		_box(capital + Vector3(side * half_size * 0.62,
				wall_height * 0.5, -half_size),
				Vector3(half_size * 0.76, wall_height, wall_thickness), "wall")
	_box(capital + Vector3(-half_size, wall_height * 0.5, 0.0),
			Vector3(wall_thickness, wall_height, half_size * 2.0), "wall")
	_box(capital + Vector3(half_size, wall_height * 0.5, 0.0),
			Vector3(wall_thickness, wall_height, half_size * 2.0), "wall")
	# Split the southern wall to leave a second gate.
	for side in [-1.0, 1.0]:
		_box(capital + Vector3(side * half_size * 0.64,
				wall_height * 0.5, half_size),
				Vector3(half_size * 0.72, wall_height, wall_thickness), "wall")

	# CAPITAL_STONE_BLOCK_DETAILS_V1
	# Decorative sandstone blocks on outer faces; no collision shapes.
	var wall_stone_rows: int = 5 if _compact else 7
	var wall_stone_row_step: float = wall_height / float(wall_stone_rows)
	var wall_stone_height: float = wall_stone_row_step * 0.68
	var wall_stone_width: float = 1.15 if _compact else 1.35
	var wall_stone_face_offset: float = wall_thickness * 0.5 + 0.02
	var wall_stone_north_face_z: float = capital.z - half_size - wall_stone_face_offset
	var wall_stone_south_face_z: float = capital.z + half_size + wall_stone_face_offset

	for wall_stone_row in range(wall_stone_rows):
		var wall_stone_y: float = (float(wall_stone_row) + 0.5) * wall_stone_row_step
		for wall_stone_segment_index in range(2):
			var wall_stone_segment_side: float = -1.0 if wall_stone_segment_index == 0 else 1.0
			var wall_stone_horizontal_count: int = 5 if _compact else 12
			for wall_stone_index in range(wall_stone_horizontal_count):
				var wall_stone_fraction: float = float(wall_stone_index) / float(maxi(1, wall_stone_horizontal_count - 1))
				var wall_stone_material: String = "rock"
				var wall_stone_shade: int = (wall_stone_row + wall_stone_index + wall_stone_segment_index) % 4
				if wall_stone_shade == 1:
					wall_stone_material = "rock_light"
				elif wall_stone_shade == 2:
					wall_stone_material = "landmark"
				elif wall_stone_shade == 3:
					wall_stone_material = "plaster_dark"
				var wall_stone_north_x: float = capital.x + wall_stone_segment_side * half_size * 0.62 + lerpf(-half_size * 0.31, half_size * 0.31, wall_stone_fraction)
				var wall_stone_south_x: float = capital.x + wall_stone_segment_side * half_size * 0.64 + lerpf(-half_size * 0.31, half_size * 0.31, wall_stone_fraction)
				_box(Vector3(wall_stone_north_x, wall_stone_y, wall_stone_north_face_z), Vector3(wall_stone_width, wall_stone_height, 0.08), wall_stone_material, false)
				_box(Vector3(wall_stone_south_x, wall_stone_y, wall_stone_south_face_z), Vector3(wall_stone_width, wall_stone_height, 0.08), wall_stone_material, false)

	# Outer faces of the two long side walls.
	var wall_side_stone_count: int = 12 if _compact else 34
	for wall_side_stone_index in range(2):
		var wall_side_stone_sign: float = -1.0 if wall_side_stone_index == 0 else 1.0
		var wall_side_stone_face_x: float = capital.x + wall_side_stone_sign * (half_size + wall_stone_face_offset)
		for wall_side_stone_block_index in range(wall_side_stone_count):
			var wall_side_stone_fraction: float = float(wall_side_stone_block_index) / float(maxi(1, wall_side_stone_count - 1))
			var wall_side_stone_z: float = capital.z + lerpf(-half_size + 3.0, half_size - 3.0, wall_side_stone_fraction)
			for wall_side_stone_row in range(wall_stone_rows):
				var wall_side_stone_y: float = (float(wall_side_stone_row) + 0.5) * wall_stone_row_step
				var wall_side_stone_shade: int = (wall_side_stone_row + wall_side_stone_block_index + wall_side_stone_index + 1) % 4
				var wall_side_stone_material: String = "rock"
				if wall_side_stone_shade == 1:
					wall_side_stone_material = "rock_light"
				elif wall_side_stone_shade == 2:
					wall_side_stone_material = "landmark"
				elif wall_side_stone_shade == 3:
					wall_side_stone_material = "plaster_dark"
				_box(Vector3(wall_side_stone_face_x, wall_side_stone_y, wall_side_stone_z), Vector3(0.08, wall_stone_height, wall_stone_width), wall_side_stone_material, false)

	# CAPITAL_ROYAL_GATE_V1
	# Decorative royal entrance frame; no new collision shapes.
	var royal_gate_z: float = gate_z - wall_thickness * 0.5 - 0.14
	var royal_gate_offset: float = half_size * 0.24
	var royal_gate_width: float = 0.9 if _compact else 1.5
	var royal_gate_depth: float = wall_thickness + 0.48
	var royal_gate_height: float = wall_height + 0.55
	var royal_gate_front_z: float = royal_gate_z - royal_gate_depth * 0.5 - 0.05

	for royal_gate_side in [-1.0, 1.0]:
		var royal_gate_x: float = capital.x + royal_gate_side * royal_gate_offset
		_box(Vector3(royal_gate_x, royal_gate_height * 0.5, royal_gate_z),
			Vector3(royal_gate_width, royal_gate_height, royal_gate_depth), "landmark", false)
		_box(Vector3(royal_gate_x, 0.24, royal_gate_z),
			Vector3(royal_gate_width + 0.38, 0.48, royal_gate_depth + 0.32), "rock_light", false)
		_box(Vector3(royal_gate_x, wall_height + 0.48, royal_gate_z),
			Vector3(royal_gate_width + 0.34, 0.38, royal_gate_depth + 0.30), "trim", false)
		_box(Vector3(royal_gate_x, wall_height * 0.52, royal_gate_front_z),
			Vector3(0.14, wall_height * 0.62, 0.07), "trim", false)

	# CAPITAL_ROYAL_GATE_DOORS_V2
	# Separate cinematic leaves; retain solid collision on both doors.
	var royal_door_height: float = wall_height - 0.18
	var royal_door_leaf_width: float = royal_gate_offset - royal_gate_width * 0.5
	var royal_door_front_z: float = royal_gate_z - royal_gate_depth * 0.5 - 0.05
	var royal_door_inside_z: float = royal_gate_z + royal_gate_depth * 0.5 + 0.05

	for royal_door_side in [-1.0, 1.0]:
		var royal_door_x: float = capital.x + royal_door_side * royal_door_leaf_width * 0.5

		# Solid wooden leaf: collision remains enabled.
		_box(Vector3(royal_door_x, royal_door_height * 0.5, royal_gate_z),
			Vector3(royal_door_leaf_width + 0.04, royal_door_height, royal_gate_depth), "wood")

		# Raised warm sandstone-coloured wooden panel on the exterior.
		_box(Vector3(royal_door_x, royal_door_height * 0.52, royal_door_front_z),
			Vector3(royal_door_leaf_width * 0.68, royal_door_height * 0.60, 0.12), "plaster_dark", false)

		# Pale-gold outer frame rails on each separate leaf.
		for royal_trim_side in [-1.0, 1.0]:
			_box(Vector3(royal_door_x + royal_trim_side * royal_door_leaf_width * 0.43,
				royal_door_height * 0.5, royal_door_front_z - 0.015),
				Vector3(0.10, royal_door_height * 0.92, 0.12), "trim", false)

		# Top and bottom decorative borders.
		for royal_trim_y in [0.16, royal_door_height - 0.16]:
			_box(Vector3(royal_door_x, royal_trim_y, royal_door_front_z - 0.015),
				Vector3(royal_door_leaf_width * 0.88, 0.10, 0.12), "trim", false)

		# Distinct centre meeting edges make the double-door split visible.
		var royal_inner_edge_x: float = royal_door_x - royal_door_side * royal_door_leaf_width * 0.49
		_box(Vector3(royal_inner_edge_x, royal_door_height * 0.5, royal_door_front_z - 0.025),
			Vector3(0.065, royal_door_height * 0.92, 0.12), "dark", false)

		# Decorative paired royal handles on the outside.
		var royal_handle_x: float = capital.x - royal_door_side * 0.18
		_box(Vector3(royal_handle_x, royal_door_height * 0.52, royal_door_front_z - 0.035),
			Vector3(0.18, 0.28, 0.12), "rock_light", false)
		_box(Vector3(royal_handle_x, royal_door_height * 0.52, royal_door_front_z - 0.055),
			Vector3(0.07, 0.14, 0.08), "dark", false)

		# Decorative brass-tone studs at the upper and lower corners.
		for royal_stud_side in [-1.0, 1.0]:
			for royal_stud_y in [0.38, royal_door_height - 0.38]:
				_box(Vector3(royal_door_x + royal_stud_side * royal_door_leaf_width * 0.34,
					royal_stud_y, royal_door_front_z - 0.07),
					Vector3(0.10, 0.10, 0.08), "rock_light", false)

		# Iron reinforcement is moved to the inside face (+Z).
		for royal_iron_side in [-1.0, 1.0]:
			_box(Vector3(royal_door_x + royal_iron_side * royal_door_leaf_width * 0.34,
				royal_door_height * 0.5, royal_door_inside_z),
				Vector3(0.12, royal_door_height * 0.84, 0.10), "dark", false)

		# Interior horizontal iron crossbars.
		for royal_iron_y in [0.30, royal_door_height * 0.72]:
			_box(Vector3(royal_door_x, royal_iron_y, royal_door_inside_z),
				Vector3(royal_door_leaf_width * 0.90, 0.12, 0.10), "dark", false)

		# CAPITAL_ROYAL_GATE_DETAILS_V3
		# Surface details only: original door leaves and their collision stay unchanged.
		var royal_door_detail_z: float = royal_door_front_z - 0.07

		# Raised timber divisions give each existing leaf a layered wooden appearance.
		for royal_plank_side in [-1.0, 0.0, 1.0]:
			_box(Vector3(royal_door_x + royal_plank_side * royal_door_leaf_width * 0.19,
				royal_door_height * 0.52, royal_door_detail_z),
				Vector3(royal_door_leaf_width * 0.075, royal_door_height * 0.43, 0.055), "wood", false)

		# Two dark metal reinforcement bands on the visible face of each leaf.
		for royal_band_y in [royal_door_height * 0.31, royal_door_height * 0.73]:
			_box(Vector3(royal_door_x, royal_band_y, royal_door_detail_z - 0.035),
				Vector3(royal_door_leaf_width * 0.72, 0.075, 0.065), "dark", false)

		# Heavy decorative hinge plates; the existing inner iron rods remain untouched.
		for royal_hinge_side in [-1.0, 1.0]:
			for royal_hinge_y in [royal_door_height * 0.25, royal_door_height * 0.77]:
				_box(Vector3(royal_door_x + royal_hinge_side * royal_door_leaf_width * 0.33,
					royal_hinge_y, royal_door_detail_z - 0.035),
					Vector3(royal_door_leaf_width * 0.12, 0.15, 0.07), "dark", false)
				_box(Vector3(royal_door_x + royal_hinge_side * royal_door_leaf_width * 0.33,
					royal_hinge_y, royal_door_detail_z - 0.078),
					Vector3(0.075, 0.075, 0.045), "rock_light", false)

	# Layered lintel spanning the gate opening.
	var royal_gate_lintel_width: float = royal_gate_offset * 2.0 + royal_gate_width + 0.38
	_box(Vector3(capital.x, wall_height + 0.37, royal_gate_z),
		Vector3(royal_gate_lintel_width, 0.58, royal_gate_depth + 0.24), "landmark", false)
	_box(Vector3(capital.x, wall_height + 0.70, royal_gate_z),
		Vector3(royal_gate_lintel_width + 0.22, 0.14, royal_gate_depth + 0.38), "trim", false)

	# Central stepped royal crest.
	var royal_gate_crest_y: float = wall_height + 1.08
	_box(Vector3(capital.x, royal_gate_crest_y, royal_gate_front_z),
		Vector3(1.55 if _compact else 2.3, 0.62, 0.16), "rock_light", false)
	_box(Vector3(capital.x, royal_gate_crest_y + 0.36, royal_gate_z),
		Vector3(1.15 if _compact else 1.8, 0.16, 0.42), "trim", false)
	_box(Vector3(capital.x, royal_gate_crest_y + 0.54, royal_gate_z),
		Vector3(0.72 if _compact else 1.15, 0.20, 0.34), "landmark", false)
	# Reinforced corner towers.
	var tower_height: float = wall_height + 1.8
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			var tower_pos: Vector3 = capital + Vector3(
					x_side * half_size, 0.0, z_side * half_size)
			_box(tower_pos + Vector3.UP * (tower_height * 0.5),
					Vector3(3.0, tower_height, 3.0), "landmark")
			_box(tower_pos + Vector3.UP * (tower_height + 0.18),
					Vector3(3.5, 0.35, 3.5), "trim", false)

	# CAPITAL_BATTLEMENT_DETAILS_V1
	# Decorative coping follows existing wall segments; gate openings stay clear.
	for side in [-1.0, 1.0]:
		_box(capital + Vector3(side * half_size * 0.62,
				wall_height + 0.08, -half_size),
				Vector3(half_size * 0.76, 0.16,
					wall_thickness + 0.24), "trim", false)
		_box(capital + Vector3(side * half_size * 0.64,
				wall_height + 0.08, half_size),
				Vector3(half_size * 0.72, 0.16,
					wall_thickness + 0.24), "trim", false)

	# Raised battlements along northern and southern wall sections.
	var crenel_count: int = 3 if _compact else 7
	for side in [-1.0, 1.0]:
		for index in range(crenel_count):
			var fraction: float = float(index) / float(maxi(1, crenel_count - 1))
			var x_offset: float = lerpf(
					-half_size * 0.29, half_size * 0.29, fraction)
			var north_x: float = capital.x + side * half_size * 0.62 + x_offset
			var south_x: float = capital.x + side * half_size * 0.64 + x_offset
			var crenel_width: float = 0.72 if _compact else 1.05
			var crenel_height: float = 0.48 if _compact else 0.68

			_box(Vector3(north_x, wall_height + 0.43, capital.z - half_size),
					Vector3(crenel_width, crenel_height,
						wall_thickness + 0.12), "landmark", false)
			_box(Vector3(south_x, wall_height + 0.43, capital.z + half_size),
					Vector3(crenel_width, crenel_height,
						wall_thickness + 0.12), "landmark", false)

	# Decorative coping and battlements along both side walls.
	for side in [-1.0, 1.0]:
		_box(capital + Vector3(side * half_size,
				wall_height + 0.08, 0.0),
				Vector3(wall_thickness + 0.24, 0.16,
					half_size * 2.0), "trim", false)

		var side_crenel_count: int = 3 if _compact else 9
		for side_index in range(side_crenel_count):
			var side_fraction: float = float(side_index) / float(
					maxi(1, side_crenel_count - 1))
			var z_offset: float = lerpf(
					-half_size + 3.0, half_size - 3.0, side_fraction)
			_box(capital + Vector3(side * half_size,
					wall_height + 0.43, z_offset),
					Vector3(wall_thickness + 0.12,
						0.48 if _compact else 0.68,
						0.72 if _compact else 1.05),
					"landmark", false)

	# Central keep and residential buildings.
	var house_scale: float = 0.62 if _compact else 1.0
	_adobe_building(capital + Vector3(-2.8, 0.0, -1.0),
			Vector3(7.0, 5.0, 7.0) * house_scale)
	_adobe_building(capital + Vector3(3.8, 0.0, 5.0),
			Vector3(5.5, 3.8, 5.0) * house_scale)
	_adobe_building(capital + Vector3(-5.8, 0.0, 5.2),
			Vector3(5.0, 3.5, 4.5) * house_scale)
	_adobe_building(capital + Vector3(5.0, 0.0, -5.5),
			Vector3(5.5, 4.0, 5.0) * house_scale)

	# Market square and defensive cover.
	_market_stall(capital + Vector3(-5.0, 0.0, -7.0))
	_market_stall(capital + Vector3(5.0, 0.0, -7.0))
	for side in [-1.0, 1.0]:
		_box(capital + Vector3(side * 7.0, 0.65, 0.0),
				Vector3(2.4, 1.3, 1.2), "sandbag")

	# Waterway on the eastern side; it is decorative, not a collision obstacle.
	var water_x: float = capital.x + half_size + (2.5 if _compact else 5.0)
	var water_y: float = 1.35
	var segment_count: int = 5 if _compact else 13
	for index in range(segment_count):
		var water_z: float = lerpf(-extent * 0.58, extent * 0.58,
				float(index) / float(maxi(1, segment_count - 1)))
		var channel_width: float = 3.0 if _compact else 5.0
		var segment_length: float = extent * 0.13
		_box(Vector3(water_x, water_y, water_z),
				Vector3(channel_width, 0.08, segment_length),
				"water", false, false)

	# Forest belts and scattered cover across the outer Heartlands.
	var tree_count: int = 22 if _compact else 76
	for index in range(tree_count):
		var point: Vector3 = _random_prop_position()
		var capital_distance: float = Vector2(
				point.x - capital.x, point.z - capital.z).length()
		if capital_distance > half_size + 7.0 and _footprint_available(
				point, Vector2(4.0, 4.0), 1.5):
			if index % 4 == 0:
				_rock_formation(point, _rng.randf_range(0.65, 1.0))
			else:
				_tree(point, _rng.randf_range(4.5, 7.0))
				if index % 3 == 0:
					_vegetation_cluster(point, _rng.randf_range(0.8, 1.25))

	# Landmark ridges at the far corners give the realm a distinct skyline.
	_landmark_formation(
			Vector3(-extent * 0.68, 0.0, -extent * 0.66),
			1.0 if _compact else 1.65)
	_rock_formation(
			Vector3(-extent * 0.66, 0.0, extent * 0.65),
			0.8 if _compact else 1.3)
	_rock_formation(
			Vector3(extent * 0.68, 0.0, extent * 0.64),
			0.75 if _compact else 1.2)

	# Low grass adds detail without adding solid collision objects.
	var grass_count: int = 12 if _compact else 42
	for index in range(grass_count):
		var grass_point: Vector3 = _random_prop_position()
		if _footprint_available(grass_point, Vector2(2.0, 2.0), 0.8):
			_grass_patch(grass_point, _rng.randf_range(0.8, 1.25))


func _build_highlands() -> void:
	_secondary_paths(3.2 if _compact else 5.5)
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
			if index % 4 == 1:
				_vegetation_cluster(point + Vector3(0.0, 0.02, 0.0), _rng.randf_range(1.0, 1.7))
	for grass_index in range(18 if _compact else 55):
		var grass_point: Vector3 = _random_prop_position()
		if _footprint_available(grass_point, Vector2(2.2, 2.2), 1.0):
			_grass_patch(grass_point, _rng.randf_range(0.8, 1.4))
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

func _vegetation_cluster(center: Vector3, scale: float) -> void:
	var blades: int = 3 if _compact else 5
	for index in range(blades):
		var angle: float = _rng.randf_range(0.0, TAU)
		var distance: float = _rng.randf_range(0.15, 1.0) * scale
		var height: float = _rng.randf_range(0.7, 1.35) * scale
		var blade_center := center + Vector3(cos(angle) * distance, height * 0.5, sin(angle) * distance)
		_instance("cone", blade_center, Vector3(0.65 * scale, height, 0.65 * scale), "leaf_light")

func _grass_patch(center: Vector3, scale: float) -> void:
	var blades: int = 3 if _compact else 5
	for index in range(blades):
		var angle: float = _rng.randf_range(0.0, TAU)
		var distance: float = _rng.randf_range(0.1, 0.8) * scale
		var height: float = _rng.randf_range(0.35, 0.75) * scale
		var blade_center := center + Vector3(cos(angle) * distance, height * 0.5, sin(angle) * distance)
		_instance("cone", blade_center, Vector3(0.32 * scale, height, 0.32 * scale), "leaf_light")

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
