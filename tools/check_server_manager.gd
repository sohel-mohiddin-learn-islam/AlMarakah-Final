extends SceneTree

func _initialize() -> void:
    call_deferred("_run_check")

func _run_check() -> void:
    print("=== SERVER PEER DIAGNOSTIC ===")

    var manager = root.get_node_or_null("NetworkManager")
    if manager == null:
        print("ERROR: NetworkManager autoload missing")
        quit(1)
        return

    var api = manager.multiplayer
    var peer = api.multiplayer_peer

    print("Manager path: ", manager.get_path())
    print("Peer class: ", peer.get_class() if peer != null else "null")
    print("Is offline peer: ", peer is OfflineMultiplayerPeer)
    print("Unique peer ID: ", api.get_unique_id())
    print("Is server: ", api.is_server())
    print("Connected peers: ", api.get_peers())

    print("=== END PEER DIAGNOSTIC ===")
    quit(0)
