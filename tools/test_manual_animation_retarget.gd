extends SceneTree

const CHARACTER_SCENE = preload("res://assets/characters/quaternius/male/Superhero_Male_FullBody.gltf")
const ANIMATION_SCENE = preload("res://assets/animations/quaternius/AnimationLibrary_Godot_Standard.gltf")

const BONE_MAP = {
    "DEF-head": "Head",
    "DEF-neck": "neck_01",

    "DEF-hand.L": "hand_l",
    "DEF-forearm.L": "lowerarm_l",
    "DEF-upper_arm.L": "upperarm_l",
    "DEF-shoulder.L": "clavicle_l",

    "DEF-hand.R": "hand_r",
    "DEF-forearm.R": "lowerarm_r",
    "DEF-upper_arm.R": "upperarm_r",
    "DEF-shoulder.R": "clavicle_r",

    "DEF-spine.003": "spine_03",
    "DEF-spine.002": "spine_02",
    "DEF-spine.001": "spine_01",

    "DEF-thigh.L": "thigh_l",
    "DEF-shin.L": "calf_l",
    "DEF-foot.L": "foot_l",
    "DEF-toe.L": "ball_leaf_l",

    "DEF-thigh.R": "thigh_r",
    "DEF-shin.R": "calf_r",
    "DEF-foot.R": "foot_r",
    "DEF-toe.R": "ball_leaf_r",

    "DEF-hips": "pelvis",
    "root": "root"
}

func _init():
    print("=== MANUAL ANIMATION RETARGET TEST ===")

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

    print("WALK_ANIMATION: ", source_animation != null)

    if source_animation == null:
        push_error("Walk animation not found")
        quit()
        return

    print("TRACK_COUNT: ", source_animation.get_track_count())

    var mapped = 0
    var skipped = 0

    for track_index in range(source_animation.get_track_count()):
        var path = source_animation.track_get_path(track_index)

        if path.get_name_count() < 2:
            skipped += 1
            continue

        var bone_name = str(path.get_name(path.get_name_count() - 1))

        if BONE_MAP.has(bone_name):
            var target_bone = BONE_MAP[bone_name]
            print("MAP: ", bone_name, " -> ", target_bone)
            mapped += 1
        else:
            skipped += 1

    print("MAPPED_TRACKS: ", mapped)
    print("SKIPPED_TRACKS: ", skipped)

    source_player.play("Walk")

    for i in range(20):
        await process_frame

    var source_head = source_skeleton.find_bone("DEF-head")
    var source_hips = source_skeleton.find_bone("DEF-hips")

    var target_head = target_skeleton.find_bone("Head")
    var target_hips = target_skeleton.find_bone("pelvis")

    print("SOURCE_HEAD: ", source_head)
    print("SOURCE_HIPS: ", source_hips)
    print("TARGET_HEAD: ", target_head)
    print("TARGET_HIPS: ", target_hips)

    print("SOURCE_HEAD_POSE: ", source_skeleton.get_bone_global_pose(source_head).origin)
    print("SOURCE_HIPS_POSE: ", source_skeleton.get_bone_global_pose(source_hips).origin)

    print("TARGET_HEAD_POSE: ", target_skeleton.get_bone_global_pose(target_head).origin)
    print("TARGET_HIPS_POSE: ", target_skeleton.get_bone_global_pose(target_hips).origin)

    print("=== MANUAL RETARGET MAPPING TEST COMPLETE ===")

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
