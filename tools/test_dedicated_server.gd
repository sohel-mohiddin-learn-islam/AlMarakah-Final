extends SceneTree

const PORT: int = 17877
const TIMEOUT: float = 10.0
const EXPECTED_CLIENTS: int = 2

var server_peer: ENetMultiplayerPeer
var client_peers: Array[ENetMultiplayerPeer] = []
var server_api: MultiplayerAPI
var client_apis: Array[MultiplayerAPI] = []

var connected_clients: Dictionary = {}
var disconnected_clients: Dictionary = {}
var started_at: int = 0
var finished: bool = false
var disconnect_started: bool = false

func _initialize() -> void:
    print("=== ALMARAKAH TWO-CLIENT ENET TEST ===")

    server_api = MultiplayerAPI.create_default_interface()
    var server_root := Node.new()
    server_root.name = "ServerTestRoot"
    root.add_child(server_root)
    set_multiplayer(server_api, NodePath("/root/ServerTestRoot"))

    server_api.peer_connected.connect(_on_server_peer_connected)
    server_api.peer_disconnected.connect(_on_server_peer_disconnected)

    server_peer = ENetMultiplayerPeer.new()
    var err: int = server_peer.create_server(PORT, 4)
    if err != OK:
        _fail("Server creation failed: %s" % err)
        return

    server_api.multiplayer_peer = server_peer

    for index in range(EXPECTED_CLIENTS):
        var api := MultiplayerAPI.create_default_interface()
        var client_root := Node.new()
        client_root.name = "ClientTestRoot%d" % index
        root.add_child(client_root)
        set_multiplayer(api, NodePath("/root/" + client_root.name))

        api.connected_to_server.connect(_on_client_connected.bind(index))
        api.connection_failed.connect(_on_client_connection_failed.bind(index))

        var peer := ENetMultiplayerPeer.new()
        err = peer.create_client("127.0.0.1", PORT)
        if err != OK:
            _fail("Client %d creation failed: %s" % [index + 1, err])
            return

        api.multiplayer_peer = peer
        client_apis.append(api)
        client_peers.append(peer)

    print("Server listening; two clients connecting...")
    started_at = Time.get_ticks_msec()
    _run_test()

func _run_test() -> void:
    while not finished:
        await process_frame
        server_api.poll()

        for api in client_apis:
            api.poll()

        var elapsed: float = float(Time.get_ticks_msec() - started_at) / 1000.0

        if connected_clients.size() == EXPECTED_CLIENTS and not disconnect_started:
            print("TWO CLIENTS CONNECTED: OK")
            if connected_clients.size() != EXPECTED_CLIENTS:
                _fail("Server peer count does not match expected clients")
                return

            print("SERVER TRACKS BOTH CLIENTS: OK")
            disconnect_started = true

            client_apis[0].multiplayer_peer = null
            client_peers[0].close()
            print("Client 1 disconnected; waiting for server notification...")

        if disconnect_started and disconnected_clients.size() == 1:
            print("SERVER DETECTED CLIENT DISCONNECT: OK")

            client_apis[1].multiplayer_peer = null
            client_peers[1].close()

            for api in client_apis:
                api.multiplayer_peer = null

            _cleanup()
            finished = true
            print("TWO-CLIENT ENET TEST: PASSED")
            quit(0)
            return

        if elapsed >= TIMEOUT:
            _fail("Two-client connection or disconnect timed out")
            return

func _on_server_peer_connected(peer_id: int) -> void:
    connected_clients[peer_id] = true
    print("Server received client peer: ", peer_id)

func _on_server_peer_disconnected(peer_id: int) -> void:
    disconnected_clients[peer_id] = true
    print("Server detected disconnected peer: ", peer_id)

func _on_client_connected(index: int) -> void:
    print("Client %d connected to server" % [index + 1])

func _on_client_connection_failed(index: int) -> void:
    _fail("Client %d connection failed" % [index + 1])

func _cleanup() -> void:
    for api in client_apis:
        api.multiplayer_peer = null

    for peer in client_peers:
        if peer != null:
            peer.close()

    client_peers.clear()

    if server_api != null:
        server_api.multiplayer_peer = null

    if server_peer != null:
        server_peer.close()
        server_peer = null

func _fail(message: String) -> void:
    if finished:
        return

    finished = true
    print("TWO-CLIENT ENET TEST: FAILED - ", message)
    _cleanup()
    quit(1)
