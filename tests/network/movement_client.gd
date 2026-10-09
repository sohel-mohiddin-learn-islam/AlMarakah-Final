extends SceneTree

const HOST: String = "127.0.0.1"
const PORT: int = 17878
const TIMEOUT: float = 12.0

class MockGame extends Node:
    var networked_match: bool = true

class TestControl extends Node:
    @rpc("authority", "reliable", "call_remote")
    func report_movement_received(movement: Vector2, aiming: bool, sprinting: bool) -> void:
        if movement.is_equal_approx(Vector2(0.0, -1.0)) and aiming and sprinting:
            print("CLIENT RECEIVED HOST MOVEMENT ACK: OK")
            quit(0)
        else:
            push_error("Host acknowledged unexpected movement values")
            quit(1)

var client_peer: ENetMultiplayerPeer
var player: Node
var started_at: int = 0
var sent_input: bool = false

func _initialize() -> void:
    call_deferred("_run_test")

func _run_test() -> void:
    var test_root := Node.new()
    test_root.name = "IntegrationRoot"
    root.add_child(test_root)

    var game := MockGame.new()
    game.name = "MockGame"
    test_root.add_child(game)

    player = load("res://scripts/player.gd").new()
    player.name = "Player"
    player.set("game", game)
    player.set_physics_process(false)
    player.set_process(false)
    test_root.add_child(player)

    var control := TestControl.new()
    control.name = "Control"
    test_root.add_child(control)

    NetworkManager.is_host = false

    client_peer = ENetMultiplayerPeer.new()
    var err: int = client_peer.create_client(HOST, PORT)
    if err != OK:
        _fail("Client could not create ENet connection: %s" % err)
        return

    multiplayer.multiplayer_peer = client_peer
    multiplayer.connected_to_server.connect(_on_connected)
    multiplayer.connection_failed.connect(_on_connection_failed)

    started_at = Time.get_ticks_msec()
    print("MOVEMENT TEST CLIENT CONNECTING")

    while true:
        await process_frame

        if multiplayer.multiplayer_peer == null:
            return

        if sent_input and Time.get_ticks_msec() - started_at > int(TIMEOUT * 1000.0):
            _fail("Timed out waiting for host acknowledgement")
            return

        if Time.get_ticks_msec() - started_at > int(TIMEOUT * 1000.0):
            _fail("Timed out connecting to movement test host")
            return

func _on_connected() -> void:
    if sent_input:
        return

    sent_input = true
    print("MOVEMENT TEST CLIENT CONNECTED: OK")

    player.rpc_id(
        1,
        "receive_network_movement",
        Vector2(0.0, -1.0),
        true,
        true
    )

func _on_connection_failed() -> void:
    _fail("Connection to movement test host failed")

func _fail(message: String) -> void:
    push_error("REAL PLAYER MOVEMENT TEST: FAILED - " + message)
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer = null
    if client_peer != null:
        client_peer.close()
    quit(1)
