extends SceneTree

const CHARACTER_SCENE = preload("res://assets/characters/quaternius/male/Superhero_Male_FullBody.gltf")
const ANIMATION_SCENE = preload("res://assets/animations/quaternius/AnimationLibrary_Godot_Standard.gltf")

func _init():
    print("=== RETARGET HIERARCHY TEST ===")

    var source = ANIMATION_SCENE.instantiate()
    var target = CHARACTER_SCENE.instantiate()

    get_root().add_child(source)
    source.add_child(target)

    var source_skeleton = find_skeleton(source)
    var target_skeleton = find_skeleton(target)
    var source_player = find_animation_player(source)

    print("SOURCE_SKELETON: ", source_skeleton != null)
    print("TARGET_SKELETON: ", target_skeleton != null)
    print("SOURCE_PLAYER: ", source_player != null)

    if source_skeleton == null or target_skeleton == null or source_player == null:
        push_error("Missing required component")
        quit()
        return

    print("SOURCE_SKELETON_PATH: ", source_skeleton.get_path())
    print("TARGET_SKELETON_PATH: ", target_skeleton.get_path())

    var profile = SkeletonProfileHumanoid.new()

    print("PROFILE_BONES:")
    for i in range(profile.get_bone_size()):
        var profile_name = profile.get_bone_name(i)
        var source_idx = source_skeleton.find_bone(profile_name)
        var target_idx = target_skeleton.find_bone(profile_name)

        if source_idx >= 0 or target_idx >= 0:
            print("  ", profile_name, " SOURCE=", source_idx, " TARGET=", target_idx)

    var bone_map = BoneMap.new()
    bone_map.set_profile(profile)

    var mappings = {
        "Hips": "pelvis",
        "Spine": "spine_01",
        "Chest": "spine_02",
        "UpperChest": "spine_03",
        "Neck": "neck_01",
        "Head": "Head",
        "LeftShoulder": "clavicle_l",
        "LeftUpperArm": "upperarm_l",
        "LeftLowerArm": "lowerarm_l",
        "LeftHand": "hand_l",
        "RightShoulder": "clavicle_r",
        "RightUpperArm": "upperarm_r",
        "RightLowerArm": "lowerarm_r",
        "RightHand": "hand_r",
        "LeftUpperLeg": "thigh_l",
        "LeftLowerLeg": "calf_l",
        "LeftFoot": "foot_l",
        "LeftToes": "ball_leaf_l",
        "RightUpperLeg": "thigh_r",
        "RightLowerLeg": "calf_r",
        "RightFoot": "foot_r",
        "RightToes": "ball_leaf_r"
    }

    for profile_name in mappings:
        bone_map.set_skeleton_bone_name(profile_name, mappings[profile_name])

    print("BONEMAP_HEAD: ", bone_map.get_skeleton_bone_name("Head"))
    print("BONEMAP_HIPS: ", bone_map.get_skeleton_bone_name("Hips"))

    var modifier = RetargetModifier3D.new()
    modifier.name = "HumanoidRetarget"
    modifier.set_profile(profile)
    modifier.set_use_global_pose(false)
    modifier.set_position_enabled(true)
    modifier.set_rotation_enabled(true)
    modifier.set_scale_enabled(true)

    target_skeleton.add_child(modifier)

    print("MODIFIER_PARENT: ", modifier.get_parent().get_path())
    print("MODIFIER_PROFILE: ", modifier.get_profile() != null)
    print("MODIFIER_ACTIVE: ", modifier.is_active())

    source_player.play("Idle")

    for i in range(5):
        await process_frame

    var target_head = target_skeleton.find_bone("Head")
    var target_hips = target_skeleton.find_bone("pelvis")

    var idle_head = target_skeleton.get_bone_global_pose(target_head)
    var idle_hips = target_skeleton.get_bone_global_pose(target_hips)

    source_player.play("Walk")

    for i in range(20):
        await process_frame

    var walk_head = target_skeleton.get_bone_global_pose(target_head)
    var walk_hips = target_skeleton.get_bone_global_pose(target_hips)

    print("IDLE_HEAD: ", idle_head.origin)
    print("WALK_HEAD: ", walk_head.origin)
    print("IDLE_HIPS: ", idle_hips.origin)
    print("WALK_HIPS: ", walk_hips.origin)

    var head_changed = idle_head != walk_head
    var hips_changed = idle_hips != walk_hips

    print("HEAD_CHANGED: ", head_changed)
    print("HIPS_CHANGED: ", hips_changed)

    if head_changed or hips_changed:
        print("=== RETARGET HIERARCHY CONNECTED ===")
    else:
        print("=== RETARGET HIERARCHY NOT CONNECTED ===")

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
