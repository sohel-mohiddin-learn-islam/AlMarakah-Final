extends SceneTree

func _initialize() -> void:
    call_deferred("_run_check")

func _run_check() -> void:
    print("=== SERVER MANAGER DIAGNOSTIC ===")

    var manager = root.get_node_or_null("NetworkManager")

    if manager == null:
        print("Autoload NetworkManager not found in root.")
        print("SERVER MANAGER TEST: FAILED")
        quit(1)
        return

    print("Using existing NetworkManager autoload.")
    print("Manager class: ", manager.get_class())
    print("Peer already assigned: ", manager.multiplayer.multiplayer_peer != null)

    var result: int = manager.host(17880)
    print("Manager host result: ", result)

    if result == OK:
        print("MANAGER HOST TEST: PASSED")
        manager.disconnect_session()
        quit(0)
    else:
        print("MANAGER HOST TEST: FAILED")
        quit(1)
