extends SceneTree

const NetworkManagerScript = preload("res://scripts/network_manager.gd")

func _initialize() -> void:
    call_deferred("_run_check")

func _run_check() -> void:
    print("=== SERVER MANAGER DIAGNOSTIC ===")

    var manager = NetworkManagerScript.new()
    root.add_child(manager)

    print("Manager added to root: ", manager.get_parent() == root)

    var peer_is_null: bool = manager.multiplayer.multiplayer_peer == null
    print("Manager multiplayer peer is null: ", peer_is_null)

    var result: int = manager.host(17880)
    print("Manager host result: ", result)

    if result == OK:
        print("MANAGER HOST TEST: PASSED")
        manager.disconnect_session()
        manager.queue_free()
        quit(0)
    else:
        print("MANAGER HOST TEST: FAILED")
        manager.queue_free()
        quit(1)
