extends CharacterBody3D
## Local third-person controller. Networking deliberately does not trust this code.
const Rules = preload("res://scripts/rules.gd")
var game: Node
var hud: CanvasLayer
var settings: RefCounted
var team: int = -1
var network_peer_id: int = 1
const MAX_HEALTH: float = 200.0
var health: float = MAX_HEALTH
var alive: bool = true
var in_vehicle: bool = false
var weapon_id: String = "rifle"
var magazine_size: int = 30
var reserve_capacity: int = 180
var weapon_damage: float = 26.0
var fire_interval: float = 0.14
var reload_seconds: float = 1.7
var move_speed: float = 7.2
var move_acceleration: float = 28.0
var move_deceleration: float = 34.0
var turn_speed: float = 14.0
var sprint_turn_speed: float = 9.5
var body_turn_speed: float = 10.0
var ads_body_turn_speed: float = 16.0
var ammo: int = 30
var reserve: int = 180
var reload_time: float = 0.0
var shot_time: float = 0.0
var yaw: float = 0.0
var pitch: float = -0.12
var ads: bool = false
var rig: Node3D
var camera: Camera3D
var arm: SpringArm3D
var body: Node3D
var sound: AudioStreamPlayer
var muzzle_flash: MeshInstance3D
var muzzle_flash_time: float = 0.0
var animator: Node
var character_visual: Node3D
var mouse_look: Vector2 = Vector2.ZERO
var network_movement: Vector2 = Vector2.ZERO
var network_input_received: bool = false
var network_position: Vector3 = Vector3.ZERO
var network_velocity: Vector3 = Vector3.ZERO
var network_yaw: float = 0.0
var network_pitch: float = -0.12
var network_alive: bool = true


func set_vehicle_visual_visible(value: bool) -> void:
	if is_instance_valid(character_visual):
		character_visual.visible = value

func restore_player_camera() -> void:
	if is_instance_valid(camera):
		camera.make_current()

func setup(game_ref: Node, spawn: Vector3, team_id: int, peer_id: int = 0) -> void:
	game = game_ref
	network_peer_id = peer_id if peer_id > 0 else multiplayer.get_unique_id()
	hud = game.hud
	settings = game.settings
	team = team_id
	position = spawn
	_configure_loadout()
	collision_layer = 2
	collision_mask = 1
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	var collider = CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	body = Node3D.new()
	add_child(body)

	var character_scene = preload("res://assets/characters/quaternius/male/Superhero_Male_FullBody.gltf")
	character_visual = character_scene.instantiate()
	character_visual.name = "RealisticCharacter"
	var animator_script = preload("res://scripts/character_animator.gd")
	animator = animator_script.new()
	character_visual.add_child(animator)
	animator.setup(character_visual)
	character_visual.position = Vector3(0, 0, 0)
	character_visual.scale = Vector3.ONE
	body.add_child(character_visual)
	rig = Node3D.new()
	rig.position = Vector3(0, 1.65, 0)
	add_child(rig)
	arm = SpringArm3D.new()
	arm.spring_length = 4.2
	arm.margin = 0.2
	arm.collision_mask = 1
	arm.add_excluded_object(get_rid())
	rig.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 75
	camera.far = 380
	arm.add_child(camera)
	if network_peer_id == multiplayer.get_unique_id():
		camera.make_current()
	_create_muzzle_flash()
	sound = AudioStreamPlayer.new()
	sound.volume_db = -18
	sound.stream = _shot_sound()
	add_child(sound)
	# Team 1 faces toward the middle as well.
	yaw = PI if spawn.z < 0 else 0.0
	rig.rotation = Vector3(pitch, yaw, 0)
	network_position = global_position
	network_velocity = velocity
	network_yaw = yaw
	network_pitch = pitch
	network_alive = alive

func _unhandled_input(event: InputEvent) -> void:
	if not alive or not is_instance_valid(game) or not game.match_active:
		return
	# Touch emulation is for lobby GUI buttons, never mouse capture or firing.
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_look += event.relative
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not OS.has_feature("mobile"):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _get_movement_input() -> Vector2:
	var movement: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back") + hud.move_vector
	return movement.limit_length()

@rpc("any_peer", "unreliable", "call_remote")
func receive_network_movement(input_vector: Vector2) -> void:
	if not is_instance_valid(game) or not game.networked_match:
		return
	if not NetworkManager.is_host:
		return
	if multiplayer.get_remote_sender_id() != network_peer_id:
		return
	network_movement = input_vector.limit_length()
	network_input_received = true

@rpc("authority", "unreliable", "call_remote")
func receive_network_snapshot(snapshot_position: Vector3, snapshot_velocity: Vector3, snapshot_yaw: float, snapshot_pitch: float, snapshot_alive: bool) -> void:
	if not is_instance_valid(game) or not game.networked_match:
		return
	if multiplayer.get_remote_sender_id() != 1:
		return
	if network_peer_id == multiplayer.get_unique_id():
		return
	network_position = snapshot_position
	network_velocity = snapshot_velocity
	network_yaw = snapshot_yaw
	network_pitch = snapshot_pitch
	network_alive = snapshot_alive

func _simulation_movement_input() -> Vector2:
	if is_instance_valid(game) and game.networked_match and multiplayer.is_server() and network_input_received and network_peer_id != multiplayer.get_unique_id():
		return network_movement
	return _get_movement_input()

func _is_local_player() -> bool:
	return network_peer_id == multiplayer.get_unique_id()

func _send_network_movement() -> void:
	if not is_instance_valid(game) or not game.networked_match or multiplayer.is_server():
		return
	receive_network_movement.rpc_id(1, _get_movement_input())

func _send_network_snapshot() -> void:
	if not is_instance_valid(game) or not game.networked_match or not multiplayer.is_server():
		return
	var snapshot := [global_position, velocity, yaw, pitch, alive]
	for peer_id in multiplayer.get_peers():
		receive_network_snapshot.rpc_id(peer_id, snapshot[0], snapshot[1], snapshot[2], snapshot[3], snapshot[4])

func _physics_process(delta: float) -> void:
	if not alive or not is_instance_valid(game) or not game.match_active:
		mouse_look = Vector2.ZERO
		return

	if in_vehicle:
		velocity = Vector3.ZERO
		return

	if game.networked_match and not multiplayer.is_server() and not _is_local_player():
		global_position = global_position.lerp(network_position, minf(delta * 14.0, 1.0))
		velocity = network_velocity
		yaw = lerp_angle(yaw, network_yaw, minf(delta * 14.0, 1.0))
		pitch = lerpf(pitch, network_pitch, minf(delta * 14.0, 1.0))
		alive = network_alive
		rig.rotation = Vector3(pitch, yaw, 0)
		if is_instance_valid(body):
			body.rotation.y = lerp_angle(body.rotation.y, yaw, minf(delta * body_turn_speed, 1.0))
		return

	_send_network_movement()

	ads = hud.aiming or (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
	if ads and hud.sprinting:
		hud.sprinting = false
	var sensitivity: float = float(settings.data.ads_sensitivity if ads else settings.data.camera_sensitivity)
	var look: Vector2 = hud.look_delta + mouse_look
	hud.look_delta = Vector2.ZERO
	mouse_look = Vector2.ZERO
	yaw -= look.x * 0.003 * sensitivity
	pitch = clampf(pitch - look.y * 0.003 * sensitivity, -1.1, 0.85)
	rig.rotation = Vector3(pitch, yaw, 0)
	var body_turn_rate: float = ads_body_turn_speed if ads else body_turn_speed
	body.rotation.y = lerp_angle(body.rotation.y, yaw, minf(delta * body_turn_rate, 1.0))
	camera.fov = lerpf(camera.fov, 46.0 if ads else 75.0, minf(delta * 12.0, 1.0))
	arm.spring_length = lerpf(arm.spring_length, 2.35 if ads else 4.2, minf(delta * 10.0, 1.0))
	var movement: Vector2 = _simulation_movement_input()
	var direction: Vector3 = Basis(Vector3.UP, yaw) * Vector3(movement.x, 0, movement.y)
	var sprinting: bool = hud.sprinting and not ads and movement.length() > 0.05
	var speed: float = move_speed * (1.35 if sprinting else (0.58 if ads else 1.0))
	var acceleration: float = move_acceleration if movement.length() > 0.05 else move_deceleration
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)

	if character_visual != null and movement.length() > 0.05:
		var target_angle := atan2(direction.x, direction.z)
		var current_turn_speed: float = sprint_turn_speed if sprinting else turn_speed
		character_visual.rotation.y = lerp_angle(
			character_visual.rotation.y,
			target_angle,
			minf(delta * current_turn_speed, 1.0)
		)
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	elif Input.is_action_just_pressed("jump") or hud.jump_requested:
		velocity.y = 8.0
	hud.jump_requested = false
	var animation_was_grounded: bool = is_on_floor()
	var animation_requested_jump: bool = Input.is_action_just_pressed("jump") or hud.jump_requested

	move_and_slide()
	_send_network_snapshot()

	if animator != null:
		if animation_requested_jump and animation_was_grounded:
			animator.play_jump_start()
		elif not animation_was_grounded and is_on_floor():
			animator.play_jump_land()
		elif not is_on_floor():
			animator.play("Jump")
		else:
			animator.update_state(movement.length(), true, ads, sprinting, delta, pitch)

	if global_position.y < -12:
		take_damage(1000)
	shot_time = maxf(0, shot_time - delta)
	if reload_time > 0:
		reload_time -= delta
		if reload_time <= 0:
			var count: int = mini(magazine_size - ammo, reserve)
			ammo += count
			reserve -= count
	if Input.is_action_just_pressed("reload") or hud.reload_requested:
		reload_weapon()
	hud.reload_requested = false
	if Input.is_action_just_pressed("vehicle_interact") or hud.vehicle_requested:
		_handle_vehicle_interaction()
	hud.vehicle_requested = false
	if muzzle_flash_time > 0.0:
		muzzle_flash_time = maxf(0.0, muzzle_flash_time - delta)
		if muzzle_flash_time <= 0.0 and is_instance_valid(muzzle_flash):
			muzzle_flash.visible = false

	var fire: bool = hud.firing or (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	if fire and shot_time <= 0 and reload_time <= 0:
		if ammo > 0:
			_shoot()
		else:
			reload_weapon()

func _nearest_vehicle() -> Node:
	if not is_instance_valid(game) or not "vehicles" in game:
		return null

	var nearest: Node = null
	var nearest_distance: float = 9.0

	for vehicle in game.vehicles:
		if not is_instance_valid(vehicle):
			continue
		if vehicle.occupied:
			continue

		var distance: float = global_position.distance_to(vehicle.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = vehicle

	return nearest

func _handle_vehicle_interaction() -> void:
	if not alive:
		return

	if in_vehicle:
		for vehicle in game.vehicles:
			if not is_instance_valid(vehicle):
				continue
			if vehicle.occupied and vehicle.driver == self:
				vehicle.exit_vehicle()
				in_vehicle = false
				return
		in_vehicle = false
		return

	var vehicle := _nearest_vehicle()
	if vehicle != null and vehicle.enter_vehicle(self):
		in_vehicle = true

func reload_weapon() -> void:
	if alive and ammo < magazine_size and reserve > 0 and reload_time <= 0:
		reload_time = reload_seconds
		if animator != null:
			animator.play_reload()

func _configure_loadout() -> void:
	var profile: Dictionary = Rules.weapon_profile(String(settings.data.get("weapon_id", "rifle")))
	weapon_id = String(profile["id"])
	magazine_size = int(profile["magazine_size"])
	reserve_capacity = int(profile["reserve"])
	weapon_damage = float(profile["damage"])
	fire_interval = float(profile["fire_interval"])
	reload_seconds = float(profile["reload_seconds"])
	move_speed = float(profile["move_speed"])
	ammo = magazine_size
	reserve = reserve_capacity
	reload_time = 0.0
	shot_time = 0.0

func _shoot() -> void:
	if animator != null:
		animator.play_shoot()
	if is_instance_valid(muzzle_flash):
		muzzle_flash.visible = true
		muzzle_flash_time = 0.05
	ammo -= 1
	shot_time = fire_interval
	var forward: Vector3 = -camera.global_basis.z
	if ads and bool(settings.data.aim_assist):
		forward = game.assisted_direction(camera.global_position, forward, self)
	var query = PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + forward * 200, 3, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var target: Vector3 = hit.get("position", camera.global_position + forward * 200)
	# Start at the character, not the camera, so cover blocks third-person shots.
	var origin: Vector3 = global_position + Vector3(0, 1.35, 0)
	game.fire_ray(origin, (target - origin).normalized(), self, weapon_damage, 200.0)
	pitch = clampf(pitch + 0.008, -1.1, 0.85)
	sound.play()

func take_damage(amount: float, attacker: Node = null) -> void:
	if not alive or amount <= 0:
		return
	health = maxf(0, health - amount)
	if is_instance_valid(hud) and hud.has_method("show_damage_indicator"):
		hud.show_damage_indicator()
	if health <= 0:
		alive = false
		set_deferred("collision_layer", 0)
		body.visible = false
		game.actor_eliminated(self, attacker)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		mouse_look = Vector2.ZERO
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _shot_sound() -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	var bytes = PackedByteArray()
	bytes.resize(1800)
	var rng = RandomNumberGenerator.new()
	rng.seed = 72
	for i in bytes.size():
		var envelope: float = pow(1.0 - float(i) / bytes.size(), 3)
		var sample: int = int(rng.randf_range(-100, 100) * envelope)
		bytes[i] = sample & 255
	stream.data = bytes
	return stream


func _create_muzzle_flash() -> void:
	if not is_instance_valid(camera):
		return
	muzzle_flash = MeshInstance3D.new()
	muzzle_flash.name = "MuzzleFlash"
	var mesh := SphereMesh.new()
	mesh.radius = 0.09
	mesh.height = 0.18
	muzzle_flash.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.72, 0.18, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.45, 0.05, 1.0)
	material.emission_energy_multiplier = 8.0
	muzzle_flash.material_override = material
	muzzle_flash.position = Vector3(0.22, -0.12, -0.75)
	muzzle_flash.visible = false
	camera.add_child(muzzle_flash)
