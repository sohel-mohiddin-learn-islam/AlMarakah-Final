extends SceneTree

var checks: int = 0
var failures: int = 0

func check(condition: bool, description: String) -> void:
    checks += 1
    if condition:
        print("PASS: ", description)
    else:
        failures += 1
        push_error("FAIL: " + description)

func _initialize() -> void:
    call_deferred("_run_tests")

func _run_tests() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    check(scene != null, "Main game scene loads")
    if scene == null:
        _finish()
        return

    var game: Node = scene.instantiate()
    check(game != null, "Main game scene instantiates")
    if game == null:
        _finish()
        return

    root.add_child(game)
    await process_frame

    check(game.has_method("_setup_network_state"), "Network state setup exists")
    check(game.has_method("_on_network_peer_joined"), "Peer-join handler exists")
    check(game.has_method("_on_network_peer_left"), "Peer-leave handler exists")
    check(game.has_method("_spawn_network_player"), "Host spawn handler exists")
    check(game.has_method("network_spawn_player"), "Client spawn handler exists")

    check(game.get("network_players") is Dictionary, "Remote-player registry exists")
    check(game.get("network_spawn_indices") is Dictionary, "Spawn-index registry exists")
    check(game.get("actors") is Array, "Actor registry exists")

    if is_instance_valid(game):
        game.queue_free()
        await process_frame

    _finish()

func _finish() -> void:
    print("ALMARAKAH MULTIPLAYER LIFECYCLE TESTS: ", checks, " checks, ", failures, " failures")
    quit(1 if failures > 0 else 0)
