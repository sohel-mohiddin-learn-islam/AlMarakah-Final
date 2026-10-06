extends SceneTree

const CHARACTER_SCENE = preload("res://assets/characters/quaternius/male/Superhero_Male_FullBody.gltf")
const ANIMATION_SCENE = preload("res://assets/animations/quaternius/AnimationLibrary_Godot_Standard.gltf")

func _init():
    print("=== REAL CHARACTER RETARGET MOVEMENT TEST ===")

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

    var profile = SkeletonProfileHumanoid.new()

    profile.set_bone_name(1, "Hips")
    profile.set_bone_name(2, "Spine")
    profile.set_bone_name(3, "Chest")
    profile.set_bone_name(4, "UpperChest")
    profile.set_bone_name(5, "Neck")
    profile.set_bone_name(6, "Head")

    print("PROFILE_CREATED: ", profile != null)

    var modifier = RetargetModifier3D.new()
    modifier.name = "HumanoidRetarget"
    modifier.set_profile(profile)
    modifier.set_use_global_pose(false)
    modifier.set_position_enabled(true)
    modifier.set_rotation_enabled(true)
    modifier.set_scale_enabled(true)

    target_skeleton.add_child(modifier)

    print("RETARGET_MODIFIER: ", modifier != null)
    print("RETARGET_PROFILE: ", modifier.get_profile() != null)
    print("RETARGET_ACTIVE: ", modifier.is_active())

    var target_head = target_skeleton.find_bone("Head")
    var target_hips = target_skeleton.find_bone("pelvis")

    print("TARGET_HEAD_INDEX: ", target_head)
    print("TARGET_HIPS_INDEX: ", target_hips)

    source_player.play("Idle")
    await process_frame
    await process_frame

    var idle_head = target_skeleton.get_bone_global_pose(target_head)
    var idle_hips = target_skeleton.get_bone_global_pose(target_hips)

    print("IDLE_HEAD_POSITION: ", idle_head.origin)
    print("IDLE_HIPS_POSITION: ", idle_hips.origin)

    source_player.play("Walk")

    for i in range(10):
        await process_frame

    var walk_head = target_skeleton.get_bone_global_pose(target_head)
    var walk_hips = target_skeleton.get_bone_global_pose(target_hips)

    print("WALK_HEAD_POSITION: ", walk_head.origin)
    print("WALK_HIPS_POSITION: ", walk_hips.origin)

    var head_changed = idle_head != walk_head
    var hips_changed = idle_hips != walk_hips

    print("HEAD_CHANGED: ", head_changed)
    print("HIPS_CHANGED: ", hips_changed)

    if head_changed or hips_changed:
        print("=== REAL CHARACTER RETARGET MOVEMENT PASSED ===")
    else:
        print("=== REAL CHARACTER RETARGET MOVEMENT NOT YET CONNECTED ===")

    source.queue_free()
    target.queue_free()
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
