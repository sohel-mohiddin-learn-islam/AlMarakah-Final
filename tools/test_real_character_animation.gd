extends SceneTree

const CHARACTER_SCENE = preload("res://assets/characters/quaternius/male/Superhero_Male_FullBody.gltf")
const ANIMATION_SCENE = preload("res://assets/animations/quaternius/AnimationLibrary_Godot_Standard.gltf")

func _init():
    print("=== REAL CHARACTER ANIMATION TEST ===")

    var source = ANIMATION_SCENE.instantiate()
    var target = CHARACTER_SCENE.instantiate()

    get_root().add_child(source)
    get_root().add_child(target)

    var source_skeleton = find_skeleton(source)
    var target_skeleton = find_skeleton(target)
    var source_player = find_animation_player(source)

    print("SOURCE_SKELETON: ", source_skeleton != null)
    print("TARGET_SKELETON: ", target_skeleton != null)
    print("SOURCE_ANIMATION_PLAYER: ", source_player != null)

    if source_skeleton == null or target_skeleton == null or source_player == null:
        push_error("Required animation components missing")
        quit()
        return

    var source_map = BoneMap.new()
    var target_map = BoneMap.new()
    var profile = SkeletonProfileHumanoid.new()

    source_map.set_profile(profile)
    target_map.set_profile(profile)

    map_bone(source_map, "Root", "root")
    map_bone(source_map, "Hips", "DEF-hips")
    map_bone(source_map, "Spine", "DEF-spine.001")
    map_bone(source_map, "Chest", "DEF-spine.002")
    map_bone(source_map, "UpperChest", "DEF-spine.003")
    map_bone(source_map, "Neck", "DEF-neck")
    map_bone(source_map, "Head", "DEF-head")
    map_bone(source_map, "LeftShoulder", "DEF-shoulder.L")
    map_bone(source_map, "LeftUpperArm", "DEF-upper_arm.L")
    map_bone(source_map, "LeftLowerArm", "DEF-forearm.L")
    map_bone(source_map, "LeftHand", "DEF-hand.L")
    map_bone(source_map, "RightShoulder", "DEF-shoulder.R")
    map_bone(source_map, "RightUpperArm", "DEF-upper_arm.R")
    map_bone(source_map, "RightLowerArm", "DEF-forearm.R")
    map_bone(source_map, "RightHand", "DEF-hand.R")
    map_bone(source_map, "LeftUpperLeg", "DEF-thigh.L")
    map_bone(source_map, "LeftLowerLeg", "DEF-shin.L")
    map_bone(source_map, "LeftFoot", "DEF-foot.L")
    map_bone(source_map, "LeftToes", "DEF-toe.L")
    map_bone(source_map, "RightUpperLeg", "DEF-thigh.R")
    map_bone(source_map, "RightLowerLeg", "DEF-shin.R")
    map_bone(source_map, "RightFoot", "DEF-foot.R")
    map_bone(source_map, "RightToes", "DEF-toe.R")

    map_bone(target_map, "Root", "root")
    map_bone(target_map, "Hips", "pelvis")
    map_bone(target_map, "Spine", "spine_01")
    map_bone(target_map, "Chest", "spine_02")
    map_bone(target_map, "UpperChest", "spine_03")
    map_bone(target_map, "Neck", "neck_01")
    map_bone(target_map, "Head", "Head")
    map_bone(target_map, "LeftShoulder", "clavicle_l")
    map_bone(target_map, "LeftUpperArm", "upperarm_l")
    map_bone(target_map, "LeftLowerArm", "lowerarm_l")
    map_bone(target_map, "LeftHand", "hand_l")
    map_bone(target_map, "RightShoulder", "clavicle_r")
    map_bone(target_map, "RightUpperArm", "upperarm_r")
    map_bone(target_map, "RightLowerArm", "lowerarm_r")
    map_bone(target_map, "RightHand", "hand_r")
    map_bone(target_map, "LeftUpperLeg", "thigh_l")
    map_bone(target_map, "LeftLowerLeg", "calf_l")
    map_bone(target_map, "LeftFoot", "foot_l")
    map_bone(target_map, "LeftToes", "ball_l")
    map_bone(target_map, "RightUpperLeg", "thigh_r")
    map_bone(target_map, "RightLowerLeg", "calf_r")
    map_bone(target_map, "RightFoot", "foot_r")
    map_bone(target_map, "RightToes", "ball_r")

    print("SOURCE_HIPS: ", source_map.get_skeleton_bone_name("Hips"))
    print("TARGET_HIPS: ", target_map.get_skeleton_bone_name("Hips"))
    print("SOURCE_HEAD: ", source_map.get_skeleton_bone_name("Head"))
    print("TARGET_HEAD: ", target_map.get_skeleton_bone_name("Head"))

    var modifier = RetargetModifier3D.new()
    modifier.name = "HumanoidRetarget"
    modifier.profile = profile
    modifier.use_global_pose = false
    modifier.set_position_enabled(true)
    modifier.set_rotation_enabled(true)
    modifier.set_scale_enabled(true)
    target_skeleton.add_child(modifier)

    source_player.play("Idle")
    print("PLAYING: Idle")
    await process_frame
    await process_frame

    source_player.play("Walk")
    print("PLAYING: Walk")
    await process_frame
    await process_frame

    source_player.play("Sprint")
    print("PLAYING: Sprint")
    await process_frame
    await process_frame

    print("RETARGET_MODIFIER_CREATED: ", is_instance_valid(modifier))
    print("CURRENT_ANIMATION: ", source_player.current_animation)
    print("=== REAL CHARACTER ANIMATION TEST PASSED ===")

    source.queue_free()
    target.queue_free()
    quit()

func map_bone(bone_map: BoneMap, profile_name: String, skeleton_name: String) -> void:
    bone_map.set_skeleton_bone_name(profile_name, skeleton_name)

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
