extends SceneTree

const CHARACTER_SCENE = preload("res://assets/characters/quaternius/male/Superhero_Male_FullBody.gltf")
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

func _init():
    print("=== REAL WALK ANIMATION TRANSFER TEST ===")

    var source = ANIMATION_SCENE.instantiate()
    var target = CHARACTER_SCENE.instantiate()

    get_root().add_child(source)
    get_root().add_child(target)

    var source_player = find_animation_player(source)
    var source_skeleton = find_skeleton(source)
    var target_skeleton = find_skeleton(target)

    print("SOURCE_PLAYER: ", source_player != null)
    print("SOURCE_SKELETON: ", source_skeleton != null)
    print("TARGET_SKELETON: ", target_skeleton != null)

    if source_player == null or source_skeleton == null or target_skeleton == null:
        push_error("Missing animation component")
        quit()
        return

    var source_animation = source_player.get_animation("Walk")

    if source_animation == null:
        push_error("Walk animation not found")
        quit()
        return

    var target_player = AnimationPlayer.new()
    target_player.name = "RetargetedAnimationPlayer"
    target.add_child(target_player)

    var library = AnimationLibrary.new()
    target_player.add_animation_library("", library)

    var retargeted = Animation.new()
    retargeted.length = source_animation.length
    retargeted.loop_mode = source_animation.loop_mode

    var mapped = 0
    var skipped = 0

    print("SOURCE_TRACKS: ", source_animation.get_track_count())

    for i in range(source_animation.get_track_count()):
        var track_type = source_animation.track_get_type(i)
        var source_path = source_animation.track_get_path(i)

        if source_path.get_subname_count() < 1:
            skipped += 1
            continue

        var source_bone = str(source_path.get_subname(0))

        if not BONE_MAP.has(source_bone):
            skipped += 1
            continue

        var target_bone = BONE_MAP[source_bone]

        var new_track = retargeted.add_track(track_type)

        var target_path = NodePath("Armature/Skeleton3D:" + target_bone)
        retargeted.track_set_path(new_track, target_path)

        retargeted.track_set_interpolation_type(
            new_track,
            source_animation.track_get_interpolation_type(i)
        )

        retargeted.track_set_interpolation_loop_wrap(
            new_track,
            source_animation.track_get_interpolation_loop_wrap(i)
        )

        var key_count = source_animation.track_get_key_count(i)

        for k in range(key_count):
            var time = source_animation.track_get_key_time(i, k)
            var value = source_animation.track_get_key_value(i, k)
            retargeted.track_insert_key(new_track, time, value)

        print("TRANSFER: ", source_bone, " -> ", target_bone, " KEYS=", key_count)
        mapped += 1

    print("MAPPED_TRACKS: ", mapped)
    print("SKIPPED_TRACKS: ", skipped)

    library.add_animation("Walk", retargeted)

    print("RETARGETED_ANIMATION_CREATED: ", library.has_animation("Walk"))
    print("RETARGETED_TRACKS: ", retargeted.get_track_count())

    var target_head = target_skeleton.find_bone("Head")
    var target_hips = target_skeleton.find_bone("pelvis")

    print("TARGET_HEAD: ", target_head)
    print("TARGET_HIPS: ", target_hips)

    var idle_head = target_skeleton.get_bone_global_pose(target_head)
    var idle_hips = target_skeleton.get_bone_global_pose(target_hips)

    print("BEFORE_HEAD: ", idle_head.origin)
    print("BEFORE_HIPS: ", idle_hips.origin)

    target_player.play("Walk")

    for i in range(30):
        await process_frame

    var walk_head = target_skeleton.get_bone_global_pose(target_head)
    var walk_hips = target_skeleton.get_bone_global_pose(target_hips)

    print("AFTER_HEAD: ", walk_head.origin)
    print("AFTER_HIPS: ", walk_hips.origin)

    var head_changed = idle_head != walk_head
    var hips_changed = idle_hips != walk_hips

    print("HEAD_CHANGED: ", head_changed)
    print("HIPS_CHANGED: ", hips_changed)

    if head_changed or hips_changed:
        print("=== REAL WALK ANIMATION TRANSFER PASSED ===")
    else:
        print("=== REAL WALK ANIMATION TRANSFER FAILED ===")

    quit()

func find_skeleton(root: Node) -> Skeleton3D:
    if root is Skeleton3D:
        return root

    for child in root.get_children():
        var result = find_skeleton(child)
        if result:
            return result

    return null

func find_animation_player(root: Node) -> AnimationPlayer:
    if root is AnimationPlayer:
        return root

    for child in root.get_children():
        var result = find_animation_player(child)
        if result:
            return result

    return null
