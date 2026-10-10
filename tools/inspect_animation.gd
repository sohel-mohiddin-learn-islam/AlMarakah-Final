extends SceneTree

const ANIMATION_SCENE = preload("res://assets/animations/quaternius/AnimationLibrary_Godot_Standard.gltf")

func _init():
    call_deferred("inspect")

func inspect():
    print("=== ANIMATION LIBRARY DIAGNOSTIC ===")
    var scene = ANIMATION_SCENE.instantiate()
    var player = find_player(scene)
    if player == null:
        print("ERROR: AnimationPlayer not found")
    else:
        print("PLAYER: ", player.get_path())
        print("LIBRARIES: ", player.get_animation_library_list())
        print("ALL CLIPS: ", player.get_animation_list())
        for library_name in player.get_animation_library_list():
            var library = player.get_animation_library(library_name)
            print("LIBRARY: [", library_name, "]")
            for clip_name in library.get_animation_list():
                print("CLIP: ", library_name, "/", clip_name)
    scene.free()
    print("=== END DIAGNOSTIC ===")
    quit()

func find_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node
    for child in node.get_children():
        var result = find_player(child)
        if result != null:
            return result
    return null
