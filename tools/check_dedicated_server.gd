extends SceneTree

func _initialize() -> void:
    print("=== ALMARAKAH DEDICATED SERVER CHECK ===")
    print("Godot version: ", Engine.get_version_info().get("string", "unknown"))

    var required_classes := [
        "ENetMultiplayerPeer",
        "WebSocketMultiplayerPeer",
        "WebSocketPeer"
    ]
    var failed := false
    for class_name_to_check in required_classes:
        var available: bool = ClassDB.class_exists(class_name_to_check)
        print(class_name_to_check, ": ", "OK" if available else "MISSING")
        if not available:
            failed = true

    var project_scene = load("res://scenes/main.tscn")
    if project_scene == null:
        print("Main scene: MISSING")
        failed = true
    else:
        print("Main scene: OK")

    if failed:
        print("DEDICATED SERVER CHECK: FAILED")
        quit(1)
    else:
        print("DEDICATED SERVER CHECK: PASSED")
        quit(0)
