extends SceneTree

const NetworkManagerScript = preload("res://scripts/network_manager.gd")

func _initialize() -> void:
    print("=== SERVER MANAGER DIAGNOSTIC ===")
    var manager = NetworkManagerScript.new()
    root.add_child(manager)

    print("Manager multiplayer peer is null: ", manager.multiplayer.multiplayer_peer == null)
    print("Root multiplayer peer is null: ", root.multiplayer.multiplayer_peer == null)
    print("Manager multiplayer API: ", manager.multiplayer)

    var result: int = manager.host(17880)
    print("Manager host result: ", result)

    if result == OK:
        print("MANAGER HOST TEST: PASSED")
        manager.disconnect_session()
        quit(0)
    else:
        print("MANAGER HOST TEST: FAILED")
        quit(1)
