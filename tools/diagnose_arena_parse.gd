extends SceneTree

func _init() -> void:
    print("=== DIRECT ARENA SCRIPT LOAD DIAGNOSTIC ===")
    var arena_script = load("res://scripts/arena.gd")
    print("ARENA_SCRIPT_LOAD_RESULT: ", arena_script)
    print("=== END ARENA SCRIPT LOAD DIAGNOSTIC ===")
    quit(0 if arena_script != null else 1)
