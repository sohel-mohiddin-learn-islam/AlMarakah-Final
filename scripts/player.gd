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
var last_movement_local_angle: float = 0.0
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
var third_person_weapon: Node3D
var weapon_muzzle: Marker3D
var weapon_recoil: float = 0.0
var weapon_recoil_rotation: float = 0.0
var weapon_attachment: BoneAttachment3D
var weapon_recoil_pivot: Node3D
var weapon_rest_position: Vector3 = Vector3.ZERO
var weapon_rest_rotation: Vector3 = Vector3.ZERO
var animator: Node
var character_visual: Node3D
var mouse_look: Vector2 = Vector2.ZERO
var network_movement: Vector2 = Vector2.ZERO
var network_aiming_input: bool = false
var network_sprinting_input: bool = false
var network_input_received: bool = false
var network_position: Vector3 = Vector3.ZERO
var network_velocity: Vector3 = Vector3.ZERO
var network_yaw: float = 0.0
var network_pitch: float = -0.12
var network_alive: bool = true
var network_movement_amount: float = 0.0
var network_aiming: bool = false
var network_sprinting: bool = false
var network_grounded: bool = true
var network_snapshot_age: float = 0.0
var network_fire_requested: bool = false
var network_fire_aiming: bool = false


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

	var character_id := "azlan"
	if settings != null and (peer_id <= 0 or peer_id == multiplayer.get_unique_id()):
		character_id = String(settings.data.get("character_id", "azlan"))
	var character_scene: PackedScene = preload("res://assets/characters/quaternius/male/Superhero_Male_FullBody.gltf")
	if character_id == "ayla":
		character_scene = preload("res://assets/characters/quaternius/male/Superhero_Female_FullBody.gltf")
	character_visual = character_scene.instantiate()
	character_visual.name = "RealisticCharacter"
	var animator_script = preload("res://scripts/character_animator.gd")
	animator = animator_script.new()
	character_visual.add_child(animator)
	animator.setup(character_visual)
	character_visual.position = Vector3(0, 0, 0)
	character_visual.scale = Vector3.ONE
	body.add_child(character_visual)
	_create_third_person_weapon()
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
	if is_instance_valid(third_person_weapon):
		if is_instance_valid(weapon_recoil_pivot):
			var aim_node := weapon_recoil_pivot.get_node_or_null("WeaponAimPivot") as Node3D
			if is_instance_valid(aim_node):
				aim_node.rotation = Vector3(clampf(-pitch * 0.55, -0.55, 0.55), 0.0, 0.0)
		else:
			third_person_weapon.rotation.x = weapon_rest_rotation.x + clampf(-pitch * 0.55, -0.55, 0.55)
			third_person_weapon.rotation.y = weapon_rest_rotation.y + angle_difference(body.rotation.y, yaw) * 0.35

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
func receive_network_movement(input_vector: Vector2, aiming_input: bool, sprinting_input: bool) -> void:
	if not is_instance_valid(game) or not game.networked_match:
		return
	if not NetworkManager.is_host:
		return
	if multiplayer.get_remote_sender_id() != network_peer_id:
		return
	network_movement = input_vector.limit_length()
	network_aiming_input = aiming_input
	network_sprinting_input = sprinting_input
	network_input_received = true
@rpc("any_peer", "unreliable", "call_remote")
func receive_network_fire(firing: bool, aiming_input: bool) -> void:
	if not is_instance_valid(game) or not game.networked_match:
		return
	if not NetworkManager.is_host:
		return
	if multiplayer.get_remote_sender_id() != network_peer_id:
		return
	network_fire_requested = firing
	network_fire_aiming = aiming_input

@rpc("any_peer", "unreliable", "call_remote")
func receive_network_look(input_yaw: float, input_pitch: float) -> void:
	if not is_instance_valid(game) or not game.networked_match:
		return
	if not NetworkManager.is_host:
		return
	if multiplayer.get_remote_sender_id() != network_peer_id:
		return
	yaw = input_yaw
	pitch = input_pitch

func _simulation_movement_input() -> Vector2:
	if is_instance_valid(game) and game.networked_match and multiplayer.is_server() and network_input_received and network_peer_id != multiplayer.get_unique_id():
		return network_movement
	return _get_movement_input()

func _is_local_player() -> bool:
	return network_peer_id == multiplayer.get_unique_id()

func _send_network_movement(aiming_input: bool, sprinting_input: bool) -> void:
	if not is_instance_valid(game) or not game.networked_match or multiplayer.is_server():
		return
	receive_network_movement.rpc_id(1, _get_movement_input(), aiming_input, sprinting_input)

func _send_network_look() -> void:
	if not is_instance_valid(game) or not game.networked_match or multiplayer.is_server():
		return
	receive_network_look.rpc_id(1, yaw, pitch)

func _send_network_fire(firing: bool, aiming_input: bool) -> void:
	if not is_instance_valid(game) or not game.networked_match or multiplayer.is_server():
		return
	receive_network_fire.rpc_id(1, firing, aiming_input)

func _physics_process(delta: float) -> void:
	weapon_recoil = lerpf(weapon_recoil, 0.0, minf(delta * 12.0, 1.0))
	weapon_recoil_rotation = lerpf(weapon_recoil_rotation, 0.0, minf(delta * 14.0, 1.0))
	if is_instance_valid(third_person_weapon):
		if is_instance_valid(weapon_recoil_pivot):
			var aim_node := weapon_recoil_pivot.get_node_or_null("WeaponAimPivot") as Node3D
			var recoil_node := weapon_recoil_pivot.get_node_or_null("WeaponAimPivot/WeaponRecoilMotion") as Node3D
			if is_instance_valid(aim_node):
				aim_node.rotation.x = clampf(-pitch * 0.55, -0.55, 0.55)
				aim_node.rotation.y = 0.0
			if is_instance_valid(recoil_node):
				recoil_node.position.z = weapon_rest_position.z + weapon_recoil * 0.12
				recoil_node.rotation.x = weapon_rest_rotation.x - weapon_recoil_rotation
		else:
			third_person_weapon.position.z = weapon_rest_position.z + weapon_recoil * 0.12
			third_person_weapon.rotation.x = weapon_rest_rotation.x + clampf(-pitch * 0.55, -0.55, 0.55) - weapon_recoil_rotation
	if not alive or not is_instance_valid(game) or not game.match_active:
		mouse_look = Vector2.ZERO
		return

	if in_vehicle:
		velocity = Vector3.ZERO
		return

	if game.networked_match and not multiplayer.is_server() and not _is_local_player():
		network_snapshot_age = minf(network_snapshot_age + delta, 0.10)
		var prediction: Vector3 = network_velocity * network_snapshot_age
		var target_position: Vector3 = network_position + prediction
		global_position = global_position.lerp(target_position, minf(delta * 16.0, 1.0))
		velocity = network_velocity
		yaw = lerp_angle(yaw, network_yaw, minf(delta * 16.0, 1.0))
		pitch = lerpf(pitch, network_pitch, minf(delta * 16.0, 1.0))
		alive = network_alive
		rig.rotation = Vector3(pitch, yaw, 0)
		if is_instance_valid(body):
			body.rotation.y = lerp_angle(body.rotation.y, yaw, minf(delta * body_turn_speed, 1.0))
		if character_visual != null:
			character_visual.rotation.y = lerp_angle(character_visual.rotation.y, 0.0, minf(delta * body_turn_speed, 1.0))
		if animator != null:
			animator.update_state(network_movement_amount, network_grounded, network_aiming, network_sprinting, delta, network_pitch, network_movement)
		return

	var is_local_player: bool = _is_local_player()
	ads = (hud.aiming or (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))) if is_local_player else (network_fire_aiming if network_fire_requested else network_aiming_input)
	if is_local_player and ads and hud.sprinting:
		hud.sprinting = false
	var sensitivity: float = float(settings.data.ads_sensitivity if ads else settings.data.camera_sensitivity)
	var look: Vector2 = hud.look_delta + mouse_look
	hud.look_delta = Vector2.ZERO
	mouse_look = Vector2.ZERO
	yaw -= look.x * 0.003 * sensitivity
	pitch = clampf(pitch - look.y * 0.003 * sensitivity, -1.1, 0.85)
	_send_network_look()
	rig.rotation = Vector3(pitch, yaw, 0)

	camera.fov = lerpf(camera.fov, 46.0 if ads else 75.0, minf(delta * 12.0, 1.0))
	arm.spring_length = lerpf(arm.spring_length, 2.35 if ads else 4.2, minf(delta * 10.0, 1.0))
	var movement: Vector2 = _simulation_movement_input()
	var direction: Vector3 = Basis(Vector3.UP, yaw) * Vector3(movement.x, 0, movement.y)
	var sprinting: bool = ((hud.sprinting if is_local_player else network_sprinting_input) and not ads and movement.length() > 0.05)
	var fire: bool = (hud.firing or (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))) if is_local_player else network_fire_requested
	if is_local_player:
		_send_network_fire(fire, ads)
	var body_turn_rate: float = ads_body_turn_speed if ads else body_turn_speed
	if movement.length() > 0.05 or ads:
		body.rotation.y = lerp_angle(body.rotation.y, yaw, minf(delta * body_turn_rate, 1.0))
	_send_network_movement(ads, sprinting)
	var speed: float = move_speed * (1.35 if sprinting else (0.58 if ads else 1.0))
	var acceleration: float = move_acceleration if movement.length() > 0.05 else move_deceleration
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)

	if character_visual != null:
		var target_local_angle: float = last_movement_local_angle
		var current_turn_speed: float = ads_body_turn_speed if ads else body_turn_speed
		if movement.length() > 0.05 and not ads and not fire:
			var movement_angle: float = atan2(direction.x, direction.z)
			last_movement_local_angle = angle_difference(yaw, movement_angle)
			target_local_angle = last_movement_local_angle
			current_turn_speed = sprint_turn_speed if sprinting else turn_speed
		elif ads or fire:
				target_local_angle = 0.0
				last_movement_local_angle = 0.0
		character_visual.rotation.y = lerp_angle(
			character_visual.rotation.y,
			target_local_angle,
			minf(delta * current_turn_speed, 1.0)
		)
	var animation_was_grounded: bool = is_on_floor()
	var animation_requested_jump: bool = Input.is_action_just_pressed("jump") or hud.jump_requested
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	elif animation_requested_jump:
		velocity.y = 8.0
	hud.jump_requested = false

	move_and_slide()
	network_movement_amount = movement.length()
	network_aiming = ads
	network_sprinting = sprinting
	network_grounded = is_on_floor()

	if animator != null:
		if animation_requested_jump and animation_was_grounded:
			animator.play_jump_start()
		elif not animation_was_grounded and is_on_floor():
			animator.play_jump_land()
		elif not is_on_floor():
			animator.play("Jump")
		else:
			animator.update_state(movement.length(), true, ads, sprinting, delta, pitch, movement)

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

	if fire and shot_time <= 0 and reload_time <= 0:
		if is_local_player and game.networked_match and not multiplayer.is_server():
			pass
		elif ammo > 0:
			_shoot()
		else:
			reload_weapon()
		if network_fire_requested:
			network_fire_requested = false

func _nearest_vehicle() -> Node:
	if not is_instance_valid(game) or not "vehicles" in game:
		return null

	var nearest: Node = null
	var nearest_distance: float = 3.0

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
	weapon_recoil = 1.0
	weapon_recoil_rotation = 0.10
	if animator != null:
		animator.play_shoot()
	if is_instance_valid(muzzle_flash):
		muzzle_flash.visible = true
		muzzle_flash_time = 0.05
	ammo -= 1
	shot_time = fire_interval
	var forward: Vector3
	var ray_origin: Vector3
	if game.networked_match and multiplayer.is_server() and not _is_local_player():
		forward = Vector3(sin(yaw) * cos(pitch), -sin(pitch), -cos(yaw) * cos(pitch)).normalized()
		ray_origin = global_position + Vector3(0, 1.35, 0)
	else:
		forward = -camera.global_basis.z
		ray_origin = camera.global_position
		if ads and bool(settings.data.aim_assist):
			forward = game.assisted_direction(ray_origin, forward, self)
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + forward * 200, 3, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var target: Vector3 = hit.get("position", ray_origin + forward * 200)

	# Third-person shots originate from the rifle muzzle but preserve camera aim.
	if is_instance_valid(weapon_muzzle):
		ray_origin = weapon_muzzle.global_position
		forward = (target - ray_origin).normalized()

	var target_direction: Vector3 = target - global_position
	target_direction.y = 0.0
	if target_direction.length_squared() > 0.001:
		var target_yaw: float = atan2(target_direction.x, target_direction.z)
		body.rotation.y = lerp_angle(body.rotation.y, target_yaw, 0.45)
		character_visual.rotation.y = 0.0
	# Fire from the rifle muzzle so the weapon and hit ray share one origin.
	game.fire_ray(ray_origin, (target - ray_origin).normalized(), self, weapon_damage, 200.0)
	if game.networked_match and multiplayer.is_server() and not _is_local_player():
		for peer_id in multiplayer.get_peers():
			game.network_play_remote_fire.rpc_id(peer_id, network_peer_id, pitch)
	pitch = clampf(pitch + 0.008, -1.1, 0.85)
	sound.play()

@rpc("authority", "reliable", "call_remote")
func receive_network_damage(new_health: float, new_alive: bool) -> void:
	if not is_instance_valid(game) or not game.networked_match:
		return
	if NetworkManager.is_host:
		return
	health = clampf(new_health, 0.0, MAX_HEALTH)
	alive = new_alive
	if network_peer_id == multiplayer.get_unique_id():
		if is_instance_valid(hud) and hud.has_method("show_damage_indicator"):
			hud.show_damage_indicator()
	if not alive:
		set_deferred("collision_layer", 0)
		if is_instance_valid(body):
			body.visible = false

func take_damage(amount: float, attacker: Node = null) -> void:
	if not alive or amount <= 0:
		return
	health = maxf(0.0, health - amount)
	if is_instance_valid(hud) and hud.has_method("show_damage_indicator"):
		hud.show_damage_indicator()
	if is_instance_valid(game) and game.networked_match and NetworkManager.is_host:
		receive_network_damage.rpc(health, health > 0.0)
	if health <= 0.0:
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


func _create_third_person_weapon() -> void:
	third_person_weapon = Node3D.new()
	third_person_weapon.name = "ThirdPersonRifle"
	third_person_weapon.position = Vector3(0.34, 1.12, -0.38)
	third_person_weapon.rotation = Vector3(0.0, 0.0, 0.0)
	body.add_child(third_person_weapon)

	var stock := MeshInstance3D.new()
	var stock_mesh := BoxMesh.new()
	stock_mesh.size = Vector3(0.16, 0.18, 0.42)
	stock.mesh = stock_mesh
	third_person_weapon.add_child(stock)

	var receiver := MeshInstance3D.new()
	var receiver_mesh := BoxMesh.new()
	receiver_mesh.size = Vector3(0.20, 0.22, 0.42)
	receiver.mesh = receiver_mesh
	receiver.position = Vector3(0.0, 0.02, -0.20)
	third_person_weapon.add_child(receiver)

	var barrel := MeshInstance3D.new()
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.045
	barrel_mesh.bottom_radius = 0.045
	barrel_mesh.height = 0.62
	barrel_mesh.radial_segments = 8
	barrel.mesh = barrel_mesh
	barrel.rotation.x = PI * 0.5
	barrel.position = Vector3(0.0, 0.03, -0.70)
	third_person_weapon.add_child(barrel)

	var handguard := MeshInstance3D.new()
	var handguard_mesh := BoxMesh.new()
	handguard_mesh.size = Vector3(0.15, 0.15, 0.38)
	handguard.mesh = handguard_mesh
	handguard.position = Vector3(0.0, 0.015, -0.48)
	third_person_weapon.add_child(handguard)

	var foregrip := MeshInstance3D.new()
	var foregrip_mesh := BoxMesh.new()
	foregrip_mesh.size = Vector3(0.085, 0.20, 0.09)
	foregrip.mesh = foregrip_mesh
	foregrip.position = Vector3(0.0, -0.15, -0.48)
	foregrip.rotation.x = -0.16
	third_person_weapon.add_child(foregrip)

	var stock_pad := MeshInstance3D.new()
	var stock_pad_mesh := BoxMesh.new()
	stock_pad_mesh.size = Vector3(0.17, 0.19, 0.07)
	stock_pad.mesh = stock_pad_mesh
	stock_pad.position = Vector3(0.0, 0.0, 0.20)
	third_person_weapon.add_child(stock_pad)

	var grip := MeshInstance3D.new()
	var grip_mesh := BoxMesh.new()
	grip_mesh.size = Vector3(0.12, 0.30, 0.14)
	grip.mesh = grip_mesh
	grip.position = Vector3(0.0, -0.20, -0.18)
	grip.rotation.x = -0.18
	third_person_weapon.add_child(grip)
	var magazine := MeshInstance3D.new()
	magazine.name = "RifleMagazine"
	var magazine_mesh := BoxMesh.new()
	magazine_mesh.size = Vector3(0.105, 0.27, 0.16)
	magazine.mesh = magazine_mesh
	magazine.position = Vector3(0.0, -0.20, -0.24)
	magazine.rotation.x = -0.12
	third_person_weapon.add_child(magazine)

	var front_sight := MeshInstance3D.new()
	front_sight.name = "RifleFrontSight"
	var front_sight_mesh := BoxMesh.new()
	front_sight_mesh.size = Vector3(0.035, 0.09, 0.045)
	front_sight.mesh = front_sight_mesh
	front_sight.position = Vector3(0.0, 0.105, -0.83)
	third_person_weapon.add_child(front_sight)

	var sight := MeshInstance3D.new()
	var sight_mesh := BoxMesh.new()
	sight_mesh.size = Vector3(0.07, 0.08, 0.18)
	sight.mesh = sight_mesh
	sight.position = Vector3(0.0, 0.16, -0.28)
	third_person_weapon.add_child(sight)

	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.045, 0.055, 0.065, 1.0)

	for part in third_person_weapon.get_children():
		if part is MeshInstance3D:
			part.material_override = dark


	var handguard_material := StandardMaterial3D.new()
	handguard_material.albedo_color = Color(0.075, 0.085, 0.09, 1.0)
	handguard.material_override = handguard_material
	foregrip.material_override = handguard_material
	var metal_material := StandardMaterial3D.new()
	metal_material.albedo_color = Color(0.16, 0.18, 0.20, 1.0)
	metal_material.metallic = 0.62
	metal_material.roughness = 0.34
	receiver.material_override = metal_material
	barrel.material_override = metal_material
	sight.material_override = metal_material
	weapon_muzzle = Marker3D.new()
	weapon_muzzle.name = "WeaponMuzzle"
	weapon_muzzle.position = Vector3(0.0, 0.03, -1.02)
	third_person_weapon.add_child(weapon_muzzle)

	var skeleton := character_visual.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton != null and skeleton.find_bone("hand_r") >= 0:
		weapon_attachment = BoneAttachment3D.new()
		weapon_attachment.name = "RightHandWeaponAttachment"
		weapon_attachment.bone_name = "hand_r"
		skeleton.add_child(weapon_attachment)
		weapon_recoil_pivot = Node3D.new()
		weapon_recoil_pivot.name = "WeaponRecoilPivot"
		weapon_attachment.add_child(weapon_recoil_pivot)
		weapon_recoil_pivot.position = Vector3(0.0, -0.18, 0.20)
		weapon_recoil_pivot.rotation = Vector3.ZERO
		var weapon_aim_pivot := Node3D.new()
		weapon_aim_pivot.name = "WeaponAimPivot"
		weapon_recoil_pivot.add_child(weapon_aim_pivot)
		var recoil_motion := Node3D.new()
		recoil_motion.name = "WeaponRecoilMotion"
		weapon_aim_pivot.add_child(recoil_motion)
		third_person_weapon.reparent(recoil_motion, false)
		third_person_weapon.position = Vector3.ZERO
		third_person_weapon.rotation = Vector3.ZERO
		weapon_rest_position = recoil_motion.position
		weapon_rest_rotation = recoil_motion.rotation
	else:
		push_warning("AlMarakah: right-hand skeleton bone not found; rifle remains body-attached")
		weapon_rest_position = third_person_weapon.position
		weapon_rest_rotation = third_person_weapon.rotation

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
	var flash_light := OmniLight3D.new()
	flash_light.name = "MuzzleFlashLight"
	flash_light.light_color = Color(1.0, 0.48, 0.12, 1.0)
	flash_light.light_energy = 2.5
	flash_light.omni_range = 3.0
	flash_light.shadow_enabled = false
	muzzle_flash.add_child(flash_light)
	muzzle_flash.position = Vector3.ZERO
	muzzle_flash.scale = Vector3(1.0, 1.0, 2.0)
	muzzle_flash.visible = false
	if is_instance_valid(weapon_muzzle):
		weapon_muzzle.add_child(muzzle_flash)
	else:
		camera.add_child(muzzle_flash)
