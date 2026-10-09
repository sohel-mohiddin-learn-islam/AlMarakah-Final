extends SceneTree

const PORT: int = 17877
const TIMEOUT: float = 8.0

var server_peer: ENetMultiplayerPeer
var client_peer: ENetMultiplayerPeer
var server_api: MultiplayerAPI
var client_api: MultiplayerAPI
var elapsed: float = 0.0
var client_connected: bool = false
var server_saw_client: bool = false
var server_saw_disconnect: bool = false
var client_peer_id: int = 0
var finished: bool = false

func _initialize() -> void:
    print("=== ALMARAKAH ENET CONNECTION TEST ===")

    server_api = MultiplayerAPI.create_default_interface()
    client_api = MultiplayerAPI.create_default_interface()

    var server_root := Node.new()
    server_root.name = "ServerTestRoot"
    root.add_child(server_root)
    server_root.set_multiplayer_authority(1)
    server_root.set_multiplayer(server_api)

    var client_root := Node.new()
    client_root.name = "ClientTestRoot"
    root.add_child(client_root)
    client_root.set_multiplayer(client_api)

    server_api.peer_connected.connect(_on_server_peer_connected)
    server_api.peer_disconnected.connect(_on_server_peer_disconnected)
    client_api.connected_to_server.connect(_on_client_connected)
    client_api.connection_failed.connect(_on_client_connection_failed)

    server_peer = ENetMultiplayerPeer.new()
    var err: int = server_peer.create_server(PORT, 4)
    if err != OK:
        _fail("Server creation failed: %s" % err)
        return
    server_api.multiplayer_peer = server_peer

    client_peer = ENetMultiplayerPeer.new()
    err = client_peer.create_client("127.0.0.1", PORT)
    if err != OK:
        _fail("Client creation failed: %s" % err)
        return
    client_api.multiplayer_peer = client_peer

    print("Server listening; local client connecting...")
    set_process(true)

func _process(delta: float) -> bool:
    if finished:
        return true

    elapsed += delta
    server_api.poll()
    client_api.poll()

    if server_saw_client and client_connected and not server_saw_disconnect:
        print("SERVER RECEIVED CLIENT: OK")
        print("CLIENT CONNECTED: OK")
        client_peer.close()
        client_peer = null
        client_api.multiplayer_peer = null
        elapsed = 0.0
        server_saw_client = false
        set_meta("disconnect_test_started", true)

    if bool(get_meta("disconnect_test_started", false)) and server_saw_disconnect:
        print("SERVER DETECTED DISCONNECT: OK")
        print("ENET CONNECTION TEST: PASSED")
        _cleanup()
        finished = true
        quit(0)
        return true

    if elapsed >= TIMEOUT:
        _fail("Connection or disconnection timed out")
        return true

    return false

func _on_server_peer_connected(peer_id: int) -> void:
    print("Server received peer: ", peer_id)
    client_peer_id = peer_id
    server_saw_client = true

func _on_server_peer_disconnected(peer_id: int) -> void:
    print("Server detected disconnected peer: ", peer_id)
    if peer_id == client_peer_id:
        server_saw_disconnect = true

func _on_client_connected() -> void:
    print("Client connected to server")
    client_connected = true

func _on_client_connection_failed() -> void:
    _fail("Client connection failed")

func _cleanup() -> void:
    if client_peer != null:
        client_peer.close()
        client_peer = null
    if server_peer != null:
        server_peer.close()
        server_peer = null

func _fail(message: String) -> void:
    if finished:
        return
    finished = true
    print("ENET CONNECTION TEST: FAILED - ", message)
    _cleanup()
    quit(1)
