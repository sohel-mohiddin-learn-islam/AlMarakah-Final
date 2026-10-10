extends SceneTree

const PORT: int = 17878
const TIMEOUT: float = 15.0

class MockGame extends Node:
    var networked_match: bool = true
    var match_active: bool = true

class TestControl extends Node:
    @rpc("authority", "reliable", "call_remote")
    func report_movement_received(movement: Vector2, aiming: bool, sprinting: bool) -> void:
        pass

var host_peer: ENetMultiplayerPeer
var player: Node
var control: Node
var finished: bool = false
var started_at: int = 0

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
    test_root.add_child(player)
    player.set_physics_process(false)
    player.set_process(false)

    control = TestControl.new()
    control.name = "Control"
    test_root.add_child(control)

    host_peer = ENetMultiplayerPeer.new()
    var err: int = host_peer.create_server(PORT, 4)
    if err != OK:
        _fail("Host could not listen on test port: %s" % err)
        return

    root.get_multiplayer().multiplayer_peer = host_peer
    NetworkManager.is_host = true
    root.get_multiplayer().peer_connected.connect(_on_peer_connected)

    print("MOVEMENT TEST HOST READY ON PORT: ", PORT)
    started_at = Time.get_ticks_msec()

    while not finished:
        await process_frame

        if bool(player.get("network_input_received")):
            var movement: Vector2 = player.get("network_movement")
            var aiming: bool = player.get("network_aiming_input")
            var sprinting: bool = player.get("network_sprinting_input")

            if movement.is_equal_approx(Vector2(0.0, -1.0)) and aiming and sprinting:
                print("REAL PLAYER MOVEMENT HANDLER: PASSED")
                control.report_movement_received.rpc_id(
                    int(player.get("network_peer_id")),
                    movement,
                    aiming,
                    sprinting
                )
                await create_timer(0.5).timeout
                _finish(0)
                return

            _fail("Host received unexpected movement input")
            return

        var elapsed := float(Time.get_ticks_msec() - started_at) / 1000.0
        if elapsed >= TIMEOUT:
            _fail("Timed out waiting for actual Player movement RPC")

func _on_peer_connected(peer_id: int) -> void:
    player.set("network_peer_id", peer_id)
    print("HOST REGISTERED TEST CLIENT: ", peer_id)

func _fail(message: String) -> void:
    print("REAL PLAYER MOVEMENT TEST: FAILED - ", message)
    _finish(1)

func _finish(code: int) -> void:
    if finished:
        return

    finished = true

    if root.get_multiplayer().multiplayer_peer != null:
        root.get_multiplayer().multiplayer_peer = null

    if host_peer != null:
        host_peer.close()

    quit(code)
