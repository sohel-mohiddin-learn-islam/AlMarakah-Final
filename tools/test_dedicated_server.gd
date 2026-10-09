extends SceneTree

const PORT: int = 17877
const TIMEOUT: float = 8.0

var server_peer: ENetMultiplayerPeer
var client_peer: ENetMultiplayerPeer
var server_api: MultiplayerAPI
var client_api: MultiplayerAPI
var started_at: int = 0
var client_connected: bool = false
var server_saw_client: bool = false
var server_saw_disconnect: bool = false
var client_peer_id: int = 0
var disconnect_started: bool = false
var finished: bool = false

func _initialize() -> void:
    print("=== ALMARAKAH ENET CONNECTION TEST ===")

    server_api = MultiplayerAPI.create_default_interface()
    client_api = MultiplayerAPI.create_default_interface()

    var server_root := Node.new()
    server_root.name = "ServerTestRoot"
    root.add_child(server_root)
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
    started_at = Time.get_ticks_msec()
    _run_test()

func _run_test() -> void:
    while not finished:
        await process_frame
        server_api.poll()
        client_api.poll()
        var elapsed: float = float(Time.get_ticks_msec() - started_at) / 1000.0

        if server_saw_client and client_connected and not disconnect_started:
            print("SERVER RECEIVED CLIENT: OK")
            print("CLIENT CONNECTED: OK")
            disconnect_started = true
            client_api.multiplayer_peer = null
            client_peer.close()
            client_peer = null

        if disconnect_started and server_saw_disconnect:
            print("SERVER DETECTED DISCONNECT: OK")
            print("ENET CONNECTION TEST: PASSED")
            _cleanup()
            finished = true
            quit(0)
            return

        if elapsed >= TIMEOUT:
            _fail("Connection or disconnection timed out")
            return

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
