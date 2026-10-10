extends SceneTree

const CHARACTER_SCENE = preload("res://assets/characters/quaternius/male/Superhero_Male_FullBody.gltf")
const ANIMATOR_SCRIPT = preload("res://scripts/character_animator.gd")

func _init() -> void:
    call_deferred("run_test")

func run_test() -> void:
    print("=== GAME CHARACTER ANIMATOR TEST ===")

    var character = CHARACTER_SCENE.instantiate()
    get_root().add_child(character)

    var skeleton = find_skeleton(character)
    if skeleton == null:
        push_error("FAIL: Character skeleton not found")
        quit(1)
        return

    var animator = ANIMATOR_SCRIPT.new()
    character.add_child(animator)
    animator.setup(character)

    await process_frame
    await process_frame

    print("SKELETON_FOUND: ", skeleton.get_path())
    print("ANIMATOR_INITIALIZED: ", animator.initialized)
    print("ANIMATION_PLAYER_FOUND: ", animator.animation_player != null)

    if animator.animation_player == null:
        push_error("FAIL: Animator did not create an AnimationPlayer")
        quit(1)
        return

    print("CREATED_ANIMATIONS: ", animator.animation_player.get_animation_list())

    if not animator.animation_player.has_animation("Walk"):
        push_error("FAIL: Walk animation was not created")
        quit(1)
        return

    var head = skeleton.find_bone("Head")
    var hips = skeleton.find_bone("pelvis")

    if head < 0 or hips < 0:
        push_error("FAIL: Target head or hips bone not found")
        quit(1)
        return

    var before_head = skeleton.get_bone_global_pose(head)
    var before_hips = skeleton.get_bone_global_pose(hips)

    animator.play("Walk")

    for i in range(20):
        await process_frame

    var after_head = skeleton.get_bone_global_pose(head)
    var after_hips = skeleton.get_bone_global_pose(hips)

    print("ANIMATION_PLAYING: ", animator.animation_player.is_playing())
    print("CURRENT_ANIMATION: ", animator.current_animation)
    print("HEAD_CHANGED: ", before_head != after_head)
    print("HIPS_CHANGED: ", before_hips != after_hips)

    if before_head != after_head or before_hips != after_hips:
        print("=== GAME CHARACTER ANIMATOR PASSED ===")
        character.queue_free()
        quit(0)
    else:
        push_error("FAIL: Walk animation did not change the skeleton pose")
        character.queue_free()
        quit(1)

func find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node

    for child in node.get_children():
        var result = find_skeleton(child)
        if result != null:
            return result

    return null
