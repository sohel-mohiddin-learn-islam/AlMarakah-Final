extends SceneTree

func _initialize() -> void:
    print("=== ENET SOCKET DIAGNOSTIC ===")
    var peer := ENetMultiplayerPeer.new()
    var result: int = peer.create_server(17879, 4)
    print("create_server result: ", result)
    print("OK constant: ", OK)
    print("ERR_ALREADY_IN_USE: ", ERR_ALREADY_IN_USE)
    print("ERR_CANT_CREATE: ", ERR_CANT_CREATE)

    if result == OK:
        print("ENET SOCKET TEST: PASSED")
        peer.close()
        quit(0)
    else:
        print("ENET SOCKET TEST: FAILED")
        quit(1)
