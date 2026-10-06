extends SceneTree

func _init() -> void:
    print("=== CHECKING character_animator.gd DIRECTLY ===")
    var script = load("res://scripts/character_animator.gd")
    if script == null:
        print("RESULT: LOAD FAILED")
        quit(1)
        return
    print("RESULT: LOAD SUCCEEDED")
    quit(0)
