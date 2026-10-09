extends SceneTree

const PORT: int = 17877
const TIMEOUT: float = 15.0

class TestEndpoint extends Node:
    signal state_received(sender_id: int, position: Vector3)

    var connected_peers: Array[int] = []
    var received_sender: int = 0
    var received_position: Vector3 = Vector3.ZERO

    @rpc("any_peer", "reliable")
    func submit_player_state(position: Vector3) -> void:
        var sender_id: int = multiplayer.get_remote_sender_id()
        if sender_id <= 1:
            return
        print("SERVER RECEIVED PLAYER STATE FROM: ", sender_id)
        for peer_id in connected_peers:
            if peer_id != sender_id:
                receive_player_state.rpc_id(peer_id, sender_id, position)

    @rpc("authority", "reliable")
    func receive_player_state(sender_id: int, position: Vector3) -> void:
        received_sender = sender_id
        received_position = position
        print("CLIENT RECEIVED PLAYER STATE FROM: ", sender_id, " POSITION: ", position)
        state_received.emit(sender_id, position)

    func register_peer(peer_id: int) -> void:
        if not connected_peers.has(peer_id):
            connected_peers.append(peer_id)
        print("SERVER REGISTERED CLIENT: ", peer_id)

    func unregister_peer(peer_id: int) -> void:
        connected_peers.erase(peer_id)
        print("SERVER REMOVED CLIENT: ", peer_id)


var server_api: MultiplayerAPI
var server_peer: ENetMultiplayerPeer
var server_endpoint: TestEndpoint

var client_apis: Array[MultiplayerAPI] = []
var client_peers: Array[ENetMultiplayerPeer] = []
var client_endpoints: Array[TestEndpoint] = []
var client_connected: Array[bool] = [false, false]
var state_received: bool = false
var disconnect_seen: bool = false
var started_at: int = 0
var finished: bool = false

func _initialize() -> void:
    print("=== ALMARAKAH TWO-CLIENT STATE SYNC TEST ===")

    server_api = MultiplayerAPI.create_default_interface()
    server_endpoint = TestEndpoint.new()
    server_endpoint.name = "ServerEndpoint"
    root.add_child(server_endpoint)
    set_multiplayer(server_api, NodePath("/root/ServerEndpoint"))

    server_api.peer_connected.connect(_on_server_peer_connected)
    server_api.peer_disconnected.connect(_on_server_peer_disconnected)

    server_peer = ENetMultiplayerPeer.new()
    var err: int = server_peer.create_server(PORT, 4)
    if err != OK:
        _fail("Server creation failed: %s" % err)
        return
    server_api.multiplayer_peer = server_peer

    for index in range(2):
        var api := MultiplayerAPI.create_default_interface()
        var endpoint := TestEndpoint.new()
        endpoint.name = "ClientEndpoint%d" % index
        root.add_child(endpoint)
        set_multiplayer(api, NodePath("/root/" + endpoint.name))

        api.connected_to_server.connect(_on_client_connected.bind(index))
        api.connection_failed.connect(_on_client_failed.bind(index))
        endpoint.state_received.connect(_on_state_received.bind(index))

        var peer := ENetMultiplayerPeer.new()
        err = peer.create_client("127.0.0.1", PORT)
        if err != OK:
            _fail("Client %d creation failed: %s" % [index + 1, err])
            return

        api.multiplayer_peer = peer
        client_apis.append(api)
        client_peers.append(peer)
        client_endpoints.append(endpoint)

    started_at = Time.get_ticks_msec()
    _run_test()

func _run_test() -> void:
    while not finished:
        await process_frame
        server_api.poll()
        for api in client_apis:
            api.poll()

        if client_connected[0] and client_connected[1] and not state_received:
            var test_position := Vector3(12.5, 0.0, -7.25)
            client_endpoints[0].submit_player_state.rpc_id(1, test_position)
            await create_timer(0.25).timeout

            if client_endpoints[1].received_sender > 1 and client_endpoints[1].received_position.is_equal_approx(test_position):
                print("TWO CLIENTS CONNECTED: OK")
                print("PLAYER STATE RELAYED THROUGH SERVER: OK")
                state_received = true

                var first_peer_id: int = client_apis[0].get_unique_id()
                client_apis[0].multiplayer_peer = null
                client_peers[0].close()
                print("CLIENT 1 DISCONNECT REQUESTED: ", first_peer_id)
            else:
                _fail("Client 2 did not receive the expected player state")
                return

        if state_received and not disconnect_seen:
            if server_endpoint.connected_peers.size() == 1:
                disconnect_seen = true
                print("SERVER DETECTED CLIENT DISCONNECT: OK")
                _cleanup()
                finished = true
                print("TWO-CLIENT STATE SYNC TEST: PASSED")
                quit(0)
                return

        var elapsed := float(Time.get_ticks_msec() - started_at) / 1000.0
        if elapsed >= TIMEOUT:
            _fail("Timed out waiting for connection, state relay, or disconnect")
            return

func _on_server_peer_connected(peer_id: int) -> void:
    server_endpoint.register_peer(peer_id)

func _on_server_peer_disconnected(peer_id: int) -> void:
    server_endpoint.unregister_peer(peer_id)

func _on_client_connected(index: int) -> void:
    client_connected[index] = true
    print("CLIENT %d CONNECTED: OK" % [index + 1])

func _on_client_failed(index: int) -> void:
    _fail("Client %d connection failed" % [index + 1])

func _on_state_received(sender_id: int, position: Vector3, index: int) -> void:
    print("STATE RECEIVED BY CLIENT %d" % [index + 1])

func _cleanup() -> void:
    for api in client_apis:
        api.multiplayer_peer = null
    for peer in client_peers:
        if peer != null:
            peer.close()
    if server_api != null:
        server_api.multiplayer_peer = null
    if server_peer != null:
        server_peer.close()
        server_peer = null

func _fail(message: String) -> void:
    if finished:
        return
    finished = true
    print("TWO-CLIENT STATE SYNC TEST: FAILED - ", message)
    _cleanup()
    quit(1)
