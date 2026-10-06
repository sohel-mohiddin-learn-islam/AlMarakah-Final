extends SceneTree

const CHARACTER_SCENE = preload("res://assets/characters/quaternius/male/Superhero_Male_FullBody.gltf")
const ANIMATION_SCENE = preload("res://assets/animations/quaternius/AnimationLibrary_Godot_Standard.gltf")

func _init():
    print("=== CHARACTER RETARGET TEST ===")

    var source = ANIMATION_SCENE.instantiate()
    var target = CHARACTER_SCENE.instantiate()

    get_root().add_child(source)
    get_root().add_child(target)

    var source_skeleton = find_skeleton(source)
    var target_skeleton = find_skeleton(target)

    print("SOURCE_SKELETON: ", source_skeleton != null)
    print("TARGET_SKELETON: ", target_skeleton != null)

    if source_skeleton:
        print("SOURCE_BONES: ", source_skeleton.get_bone_count())
        for i in range(source_skeleton.get_bone_count()):
            print("SOURCE_BONE: ", i, " = ", source_skeleton.get_bone_name(i))

    if target_skeleton:
        print("TARGET_BONES: ", target_skeleton.get_bone_count())
        for i in range(target_skeleton.get_bone_count()):
            print("TARGET_BONE: ", i, " = ", target_skeleton.get_bone_name(i))

    print("RETARGET_CLASS: ", ClassDB.class_exists("RetargetModifier3D"))

    source.queue_free()
    target.queue_free()

    print("=== END CHARACTER RETARGET TEST ===")
    quit()

func find_skeleton(root: Node) -> Skeleton3D:
    if root is Skeleton3D:
        return root

    for child in root.get_children():
        var result = find_skeleton(child)
        if result:
            return result

    return null
