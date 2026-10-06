extends Node

const ANIMATION_SCENE = preload("res://assets/animations/quaternius/AnimationLibrary_Godot_Standard.gltf")

const BONE_MAP = {
	"root": "root",
	"DEF-hips": "pelvis",
	"DEF-spine.001": "spine_01",
	"DEF-spine.002": "spine_02",
	"DEF-spine.003": "spine_03",
	"DEF-neck": "neck_01",
	"DEF-head": "Head",
	"DEF-shoulder.L": "clavicle_l",
	"DEF-upper_arm.L": "upperarm_l",
	"DEF-forearm.L": "lowerarm_l",
	"DEF-hand.L": "hand_l",
	"DEF-shoulder.R": "clavicle_r",
	"DEF-upper_arm.R": "upperarm_r",
	"DEF-forearm.R": "lowerarm_r",
	"DEF-hand.R": "hand_r",
	"DEF-thigh.L": "thigh_l",
	"DEF-shin.L": "calf_l",
	"DEF-foot.L": "foot_l",
	"DEF-toe.L": "ball_leaf_l",
	"DEF-thigh.R": "thigh_r",
	"DEF-shin.R": "calf_r",
	"DEF-foot.R": "foot_r",
	"DEF-toe.R": "ball_leaf_r"
}

var character: Node
var animation_player: AnimationPlayer
var source_player: AnimationPlayer
var current_animation: String = ""
var initialized: bool = false
var shoot_timer: float = 0.0
var reload_timer: float = 0.0

func setup(character_root: Node) -> void:
	character = character_root

	var source_scene = ANIMATION_SCENE.instantiate()
	source_player = _find_animation_player(source_scene)

	if source_player == null:
		push_error("CharacterAnimator: source AnimationPlayer not found")
		if source_scene != null:
			source_scene.free()
		return

	animation_player = AnimationPlayer.new()
	animation_player.name = "CharacterAnimationPlayer"
	character.add_child(animation_player)

	var library = AnimationLibrary.new()
	animation_player.add_animation_library("", library)

	var animation_names = [
		"Idle",
		"Walk",
		"Jog_Fwd",
		"Sprint",
		"Jump_Start",
		"Jump",
		"Jump_Land",
		"Pistol_Idle",
		"Pistol_Aim_Neutral",
		"Pistol_Aim_Up",
		"Pistol_Aim_Down",
		"Pistol_Shoot",
		"Pistol_Reload"
	]

	for animation_name in animation_names:
		var source_animation = source_player.get_animation(animation_name)

		if source_animation == null:
			print("CharacterAnimator: missing ", animation_name)
			continue

		var retargeted = _retarget_animation(source_animation)

		if retargeted != null:
			library.add_animation(animation_name, retargeted)
			print("CharacterAnimator: created ", animation_name)

	if source_scene != null:
		source_scene.free()

	source_player = null
	initialized = true
	play("Idle")

func _retarget_animation(source_animation: Animation) -> Animation:
	var retargeted = Animation.new()
	retargeted.length = source_animation.length
	retargeted.loop_mode = source_animation.loop_mode

	for i in range(source_animation.get_track_count()):
		var track_type = source_animation.track_get_type(i)
		var source_path = source_animation.track_get_path(i)

		if source_path.get_subname_count() < 1:
			continue

		var source_bone = str(source_path.get_subname(0))

		if not BONE_MAP.has(source_bone):
			continue

		var target_bone = BONE_MAP[source_bone]
		var new_track = retargeted.add_track(track_type)

		retargeted.track_set_path(
			new_track,
			NodePath("Armature/Skeleton3D:" + target_bone)
		)

		retargeted.track_set_interpolation_type(
			new_track,
			source_animation.track_get_interpolation_type(i)
		)

		retargeted.track_set_interpolation_loop_wrap(
			new_track,
			source_animation.track_get_interpolation_loop_wrap(i)
		)

		for k in range(source_animation.track_get_key_count(i)):
			retargeted.track_insert_key(
				new_track,
				source_animation.track_get_key_time(i, k),
				source_animation.track_get_key_value(i, k)
			)

	return retargeted

func play(animation_name: String, blend: float = 0.20) -> void:
	if not initialized or animation_player == null:
		return

	if not animation_player.has_animation(animation_name):
		return

	if current_animation == animation_name and animation_player.is_playing():
		return

	current_animation = animation_name
	animation_player.play(animation_name, blend)

func update_state(movement_amount: float, grounded: bool, aiming: bool, sprinting: bool, delta: float, aim_pitch: float = 0.0) -> void:
	if not initialized:
		return

	shoot_timer = maxf(0.0, shoot_timer - delta)
	reload_timer = maxf(0.0, reload_timer - delta)

	if shoot_timer > 0.0 or reload_timer > 0.0:
		return

	if not grounded:
		if velocity_is_falling():
			play("Jump")
		return

	if aiming:
		if aim_pitch < -0.28:
			play("Pistol_Aim_Up")
		elif aim_pitch > 0.28:
			play("Pistol_Aim_Down")
		elif movement_amount > 0.15:
			play("Pistol_Aim_Neutral")
		else:
			play("Pistol_Aim_Neutral")
		return

	if sprinting and movement_amount > 0.05:
		play("Sprint")
	elif movement_amount < 0.05:
		play("Idle")
	elif movement_amount < 0.35:
		play("Walk")
	else:
		play("Jog_Fwd")

func velocity_is_falling() -> bool:
	if character == null:
		return false

	var player = character.get_parent()

	if player is CharacterBody3D:
		return player.velocity.y <= 0.0

	return false

func play_jump_start() -> void:
	if not initialized:
		return

	play("Jump_Start", 0.05)

func play_jump_land() -> void:
	if not initialized:
		return

	play("Jump_Land", 0.05)

func play_shoot() -> void:
	if not initialized:
		return

	shoot_timer = 0.22
	play("Pistol_Shoot", 0.04)

func play_reload() -> void:
	if not initialized:
		return

	reload_timer = 1.0
	play("Pistol_Reload", 0.08)

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root

	for child in root.get_children():
		var result = _find_animation_player(child)

		if result != null:
			return result

	return null
