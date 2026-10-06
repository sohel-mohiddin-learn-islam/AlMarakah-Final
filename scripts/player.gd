extends CharacterBody3D
## Local third-person controller. Networking deliberately does not trust this code.
const Rules = preload("res://scripts/rules.gd")
var game: Node
var hud: CanvasLayer
var settings: RefCounted
var team: int = -1
var health: float = 100.0
var alive: bool = true
var weapon_id: String = "rifle"
var magazine_size: int = 30
var reserve_capacity: int = 180
var weapon_damage: float = 26.0
var fire_interval: float = 0.14
var reload_seconds: float = 1.7
var move_speed: float = 7.2
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
var animator: Node
var mouse_look: Vector2 = Vector2.ZERO

func setup(game_ref: Node, spawn: Vector3, team_id: int) -> void:
	game = game_ref
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
	var character_visual = character_scene.instantiate()
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
	camera.make_current()
	sound = AudioStreamPlayer.new()
	sound.volume_db = -18
	sound.stream = _shot_sound()
	add_child(sound)
	# Team 1 faces toward the middle as well.
	yaw = PI if spawn.z < 0 else 0.0
	rig.rotation = Vector3(pitch, yaw, 0)

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

func _physics_process(delta: float) -> void:
	if not alive or not is_instance_valid(game) or not game.match_active:
		mouse_look = Vector2.ZERO
		return
	ads = hud.aiming or (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
	var sensitivity: float = float(settings.data.ads_sensitivity if ads else settings.data.camera_sensitivity)
	var look: Vector2 = hud.look_delta + mouse_look
	hud.look_delta = Vector2.ZERO
	mouse_look = Vector2.ZERO
	yaw -= look.x * 0.003 * sensitivity
	pitch = clampf(pitch - look.y * 0.003 * sensitivity, -1.1, 0.85)
	rig.rotation = Vector3(pitch, yaw, 0)
	body.rotation.y = yaw
	camera.fov = lerpf(camera.fov, 49.0 if ads else 75.0, minf(delta * 12.0, 1.0))
	arm.spring_length = lerpf(arm.spring_length, 2.6 if ads else 4.2, minf(delta * 10.0, 1.0))
	var movement: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back") + hud.move_vector
	movement = movement.limit_length()
	var direction: Vector3 = Basis(Vector3.UP, yaw) * Vector3(movement.x, 0, movement.y)
	var speed: float = move_speed * (0.58 if ads else 1.0)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	elif Input.is_action_just_pressed("jump") or hud.jump_requested:
		velocity.y = 8.0
	hud.jump_requested = false
	var animation_was_grounded: bool = is_on_floor()
	var animation_requested_jump: bool = Input.is_action_just_pressed("jump") or hud.jump_requested

	move_and_slide()

	if animator != null:
		if animation_requested_jump and animation_was_grounded:
			animator.play_jump_start()
		elif not animation_was_grounded and is_on_floor():
			animator.play_jump_land()
		elif not is_on_floor():
			animator.play("Jump")
		else:
			animator.update_state(movement.length(), true, ads, delta)

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
	var fire: bool = hud.firing or (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	if fire and shot_time <= 0 and reload_time <= 0:
		if ammo > 0:
			_shoot()
		else:
			reload_weapon()

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
