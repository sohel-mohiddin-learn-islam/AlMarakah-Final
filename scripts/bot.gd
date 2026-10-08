extends CharacterBody3D
## Cheap, deliberately imperfect offline opponents. All positions use feet as origin.

const RUN_SPEED: float = 5.2
const GRAVITY: float = 22.0
const SIGHT_RANGE: float = 90.0
const EYE_HEIGHT: Vector3 = Vector3(0.0, 1.25, 0.0)
const AIM_HEIGHT: Vector3 = Vector3(0.0, 1.1, 0.0)

# Shared resources keep 49 opponents small; each actor owns only three mesh instances.
static var _body_mesh: CapsuleMesh
static var _head_mesh: SphereMesh
static var _gun_mesh: BoxMesh
static var _body_shape: CapsuleShape3D
static var _uniforms: Array[StandardMaterial3D] = []
static var _dark_material: StandardMaterial3D

var game: Node
const MAX_HEALTH: float = 200.0
var health: float = MAX_HEALTH
var team: int = -1
var alive: bool = true
var network_replica: bool = false
var network_id: int = 0
var network_position: Vector3 = Vector3.ZERO
var network_velocity: Vector3 = Vector3.ZERO
var network_yaw: float = 0.0
var network_alive: bool = true

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _visual: Node3D
var _collider: CollisionShape3D
var _target: Node3D
var _visible_target: bool = false
var _sense_left: float = 0.0
var _steer_left: float = 0.0
var _shot_left: float = 0.0
var _reaction_left: float = 0.0
var _wander_left: float = 0.0
var _strafe_left: float = 0.0
var _strafe_sign: float = 1.0
var _wander_goal: Vector3 = Vector3.ZERO
var _move_direction: Vector3 = Vector3.ZERO
var _face_direction: Vector3 = Vector3.FORWARD
var _move_speed: float = RUN_SPEED
var _avoid_left: float = 0.0
var _avoid_direction: Vector3 = Vector3.ZERO
var _wall_normal: Vector3 = Vector3.ZERO
var _los_query: PhysicsRayQueryParameters3D
var _probe_query: PhysicsRayQueryParameters3D


func setup(game_ref: Node, spawn_position: Vector3, team_id: int) -> void:
	# The caller adds us to the tree before setup, so global_position and RID are valid.
	game = game_ref
	team = team_id
	health = MAX_HEALTH
	alive = true
	global_position = spawn_position
	velocity = Vector3.ZERO
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.35
	max_slides = 3
	_rng.randomize()
	_sense_left = _rng.randf_range(0.05, 0.95)
	_steer_left = _rng.randf_range(0.02, 0.3)
	_shot_left = _rng.randf_range(0.7, 1.5)
	_reaction_left = 0.5
	_wander_left = 0.0
	_strafe_left = 0.0
	_avoid_left = 0.0
	_target = null
	_visible_target = false
	_move_direction = Vector3.ZERO
	_wall_normal = Vector3.ZERO
	_make_body()
	_los_query = PhysicsRayQueryParameters3D.new()
	_los_query.collision_mask = 3
	_los_query.exclude = [get_rid()]
	_probe_query = PhysicsRayQueryParameters3D.new()
	_probe_query.collision_mask = 1
	_probe_query.exclude = [get_rid()]
	set_physics_process(true)


func setup_network_replica(game_ref: Node, spawn_position: Vector3, team_id: int, replica_id: int) -> void:
	game = game_ref
	team = team_id
	network_replica = true
	network_id = replica_id
	health = MAX_HEALTH
	alive = true
	network_alive = true
	global_position = spawn_position
	velocity = Vector3.ZERO
	network_position = spawn_position
	network_velocity = Vector3.ZERO
	network_yaw = 0.0
	collision_layer = 0
	collision_mask = 0
	_make_body()
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if network_replica:
		if not alive or not is_instance_valid(game) or not game.match_active:
			return
		global_position = global_position.lerp(network_position, minf(delta * 14.0, 1.0))
		velocity = network_velocity
		alive = network_alive
		if is_instance_valid(_visual):
			_visual.rotation.y = network_yaw
		return
	if not alive or not is_instance_valid(game) or not game.match_active:
		velocity = Vector3.ZERO
		return
	_sense_left -= delta
	_steer_left -= delta
	_shot_left -= delta
	_reaction_left -= delta
	_wander_left -= delta
	_strafe_left -= delta
	_avoid_left -= delta
	if _sense_left <= 0.0:
		_sense_left = _rng.randf_range(0.75, 1.15)
		_select_target()
	if _steer_left <= 0.0:
		_steer_left = _rng.randf_range(0.22, 0.34)
		_update_intent()
	if _visible_target and _shot_left <= 0.0 and _reaction_left <= 0.0:
		_try_fire()
	velocity.x = _move_direction.x * _move_speed
	velocity.z = _move_direction.z * _move_speed
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	# Slide contacts catch capsule-edge collisions that the forward ray might miss.
	for index in range(get_slide_collision_count()):
		var normal: Vector3 = get_slide_collision(index).get_normal()
		if absf(normal.y) < 0.5:
			_wall_normal = Vector3(normal.x, 0.0, normal.z).normalized()
			break
	if not _face_direction.is_zero_approx():
		var yaw: float = atan2(-_face_direction.x, -_face_direction.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, yaw, minf(delta * 7.0, 1.0))
		network_yaw = _visual.rotation.y


func _valid_enemy(actor: Node3D) -> bool:
	return is_instance_valid(actor) and actor != self and bool(actor.get("alive")) \
		and is_instance_valid(game) and bool(game.are_enemies(self, actor))


func _select_target() -> void:
	# One cheap actor scan per second, not 49 full scans or ray fans every frame.
	var nearest: Node3D = null
	var best_score: float = SIGHT_RANGE * SIGHT_RANGE
	var actors: Array = game.actors
	for actor in actors:
		if not (actor is Node3D) or not _valid_enemy(actor):
			continue
		var distance_squared: float = global_position.distance_squared_to(actor.global_position)
		if distance_squared > SIGHT_RANGE * SIGHT_RANGE:
			continue
		# Mild target retention avoids flickering between similarly distant opponents.
		var score: float = distance_squared * (0.8 if actor == _target else 1.0)
		if score < best_score:
			best_score = score
			nearest = actor
	if nearest != _target:
		_target = nearest
		_visible_target = false
		_reaction_left = _rng.randf_range(0.45, 0.85)


func _update_intent() -> void:
	if _strafe_left <= 0.0:
		_strafe_left = _rng.randf_range(1.6, 3.4)
		_strafe_sign = -1.0 if _rng.randf() < 0.5 else 1.0
	if not _valid_enemy(_target):
		_target = null
	var was_visible: bool = _visible_target
	_visible_target = _target != null and _has_line_of_sight(_target)
	if _visible_target and not was_visible:
		_reaction_left = _rng.randf_range(0.4, 0.75)
	var desired: Vector3 = Vector3.ZERO
	_move_speed = RUN_SPEED
	var flat_position: Vector3 = Vector3(global_position.x, 0.0, global_position.z)
	var safe_radius: float = maxf(1.0, float(game.zone_radius) - 7.0)
	var returning_to_zone: bool = not bool(game.is_cs) \
		and flat_position.length_squared() > safe_radius * safe_radius
	if returning_to_zone:
		# Zone survival takes priority over chasing, even when an enemy is outside it.
		desired = -flat_position.normalized()
	elif _target != null:
		var offset: Vector3 = _target.global_position - global_position
		offset.y = 0.0
		var distance: float = offset.length()
		var forward: Vector3 = offset.normalized()
		if not _visible_target or distance > 24.0:
			desired = forward
		else:
			var approach: float = 0.35 if distance > 15.0 else 0.0
			if distance < 9.0:
				approach = -0.65
			var sideways: Vector3 = Vector3(-forward.z, 0.0, forward.x) * _strafe_sign
			desired = (forward * approach + sideways * 0.8).normalized()
			_move_speed = RUN_SPEED * 0.7
	else:
		if _wander_left <= 0.0 or flat_position.distance_to(_wander_goal) < 2.5:
			_wander_left = _rng.randf_range(3.0, 5.0)
			var roam_radius: float = 20.0 if bool(game.is_cs) else minf(65.0, safe_radius * 0.6)
			var angle: float = _rng.randf_range(0.0, TAU)
			_wander_goal = Vector3(sin(angle), 0.0, cos(angle)) \
				* _rng.randf_range(0.15, 1.0) * roam_radius
		desired = (_wander_goal - flat_position).normalized()
	_move_direction = _avoid_obstacles(desired)
	_face_direction = _move_direction
	if _visible_target:
		_face_direction = _target.global_position - global_position
		_face_direction.y = 0.0


func _avoid_obstacles(desired: Vector3) -> Vector3:
	if desired.is_zero_approx():
		return Vector3.ZERO
	if _avoid_left > 0.0:
		desired = (desired * 0.35 + _avoid_direction).normalized()
	_probe_query.from = global_position + Vector3(0.0, 0.7, 0.0)
	_probe_query.to = _probe_query.from + desired * 2.7
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(_probe_query)
	var normal: Vector3 = _wall_normal
	_wall_normal = Vector3.ZERO
	if not hit.is_empty():
		normal = hit["normal"]
		normal.y = 0.0
		normal = normal.normalized()
	if normal.is_zero_approx():
		return desired
	var tangent: Vector3 = Vector3(-normal.z, 0.0, normal.x)
	var alignment: float = tangent.dot(desired)
	if absf(alignment) < 0.15:
		tangent *= _strafe_sign
	elif alignment < 0.0:
		tangent = -tangent
	# Only cast the extra side probe when actually blocked.
	_probe_query.to = _probe_query.from + (tangent + normal * 0.3).normalized() * 2.5
	if not get_world_3d().direct_space_state.intersect_ray(_probe_query).is_empty():
		tangent = -tangent
	_avoid_direction = (tangent + normal * 0.3).normalized()
	_avoid_left = 0.9
	return _avoid_direction


func _has_line_of_sight(actor: Node3D) -> bool:
	if not _valid_enemy(actor):
		return false
	_los_query.from = global_position + EYE_HEIGHT
	_los_query.to = actor.global_position + AIM_HEIGHT
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(_los_query)
	# Actors (including teammates) and map cover both block shots; self is excluded.
	return hit.is_empty() or hit.get("collider") == actor


func _try_fire() -> void:
	_shot_left = _rng.randf_range(0.55, 0.95)
	# Recheck at the instant of firing, not just against cached perception.
	if not _valid_enemy(_target) or not _has_line_of_sight(_target):
		_visible_target = false
		return
	var origin: Vector3 = global_position + EYE_HEIGHT
	var aim: Vector3 = _target.global_position + AIM_HEIGHT
	if origin.distance_squared_to(aim) > SIGHT_RANGE * SIGHT_RANGE:
		return
	var direction: Vector3 = (aim - origin).normalized()
	var right: Vector3 = direction.cross(Vector3.UP).normalized()
	var spread: float = 0.035 if bool(game.is_cs) else 0.045
	direction = (direction + right * _rng.randf_range(-spread, spread) \
		+ Vector3.UP * _rng.randf_range(-spread * 0.75, spread * 0.75)).normalized()
	if _rng.randf() < 0.2:
		_shot_left += _rng.randf_range(0.5, 1.0)
	# No prediction, headshot bonus or instant lock-on. A player gets time to react.
	game.fire_ray(origin, direction, self, 9.0, SIGHT_RANGE)


@rpc("authority", "reliable", "call_remote")
func receive_network_damage(new_health: float, new_alive: bool) -> void:
	if not network_replica:
		return
	health = clampf(new_health, 0.0, MAX_HEALTH)
	alive = new_alive
	network_alive = new_alive
	if not alive:
		velocity = Vector3.ZERO
		collision_layer = 0
		collision_mask = 0
		if is_instance_valid(_collider):
			_collider.set_deferred("disabled", true)
		if is_instance_valid(_visual):
			_visual.rotation.z = PI * 0.5
			_visual.position.y = 0.35
		set_physics_process(false)

func set_network_eliminated() -> void:
	network_alive = false
	alive = false
	velocity = Vector3.ZERO
	_target = null
	_visible_target = false
	collision_layer = 0
	collision_mask = 0
	if is_instance_valid(_collider):
		_collider.set_deferred("disabled", true)
	if is_instance_valid(_visual):
		_visual.rotation.z = PI * 0.5
		_visual.position.y = 0.35
	set_physics_process(false)

func take_damage(amount: float, attacker: Node = null) -> void:
	if not alive or amount <= 0.0 or not is_finite(amount):
		return
	health = maxf(0.0, health - amount)
	if is_instance_valid(game) and game.networked_match and NetworkManager.is_host:
		receive_network_damage.rpc(health, health > 0.0)
	if health > 0.0:
		return
	alive = false
	velocity = Vector3.ZERO
	_target = null
	_visible_target = false
	collision_layer = 0
	collision_mask = 0
	if is_instance_valid(_collider):
		_collider.set_deferred("disabled", true)
	if is_instance_valid(_visual):
		_visual.rotation.z = PI * 0.5
		_visual.position.y = 0.35
	set_physics_process(false)
	# Keep the actor and its corpse for the roster; the match owns eventual cleanup.
	if is_instance_valid(game):
		game.actor_eliminated(self, attacker)

func _make_body() -> void:
	if _body_mesh == null:
		_body_mesh = CapsuleMesh.new()
		_body_mesh.radius = 0.34
		_body_mesh.height = 1.1
		_body_mesh.radial_segments = 8
		_body_mesh.rings = 3
		_head_mesh = SphereMesh.new()
		_head_mesh.radius = 0.24
		_head_mesh.height = 0.48
		_head_mesh.radial_segments = 8
		_head_mesh.rings = 3
		_gun_mesh = BoxMesh.new()
		_gun_mesh.size = Vector3(0.15, 0.17, 0.7)
		_body_shape = CapsuleShape3D.new()
		_body_shape.radius = 0.42
		_body_shape.height = 1.8
		for color in [Color("be684f"), Color("428fc1"), Color("d6a148")]:
			var uniform: StandardMaterial3D = StandardMaterial3D.new()
			uniform.albedo_color = color
			uniform.roughness = 1.0
			_uniforms.append(uniform)
		_dark_material = StandardMaterial3D.new()
		_dark_material.albedo_color = Color("293943")
		_dark_material.roughness = 0.9
	# setup can also reset an existing actor without duplicating its render nodes.
	if is_instance_valid(_visual):
		_visual.rotation = Vector3.ZERO
		_visual.position = Vector3.ZERO
		var torso: MeshInstance3D = _visual.get_child(0) as MeshInstance3D
		torso.material_override = _uniforms[0 if team < 0 else 1 + posmod(team, 2)]
		_collider.set_deferred("disabled", false)
		return
	_visual = Node3D.new()
	_visual.name = "BotBody"
	add_child(_visual)
	var uniform_index: int = 0 if team < 0 else 1 + posmod(team, 2)
	_add_mesh(_body_mesh, _uniforms[uniform_index], Vector3(0.0, 0.86, 0.0))
	_add_mesh(_head_mesh, _dark_material, Vector3(0.0, 1.55, 0.0))
	_add_mesh(_gun_mesh, _dark_material, Vector3(0.34, 1.08, -0.33))
	_collider = CollisionShape3D.new()
	_collider.name = "BodyCollider"
	_collider.shape = _body_shape
	_collider.position.y = 0.9
	add_child(_collider)


func _add_mesh(mesh: Mesh, material: Material, offset: Vector3) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = offset
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(instance)
