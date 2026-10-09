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

    check(game.has_method("_setup_network_state"), "Game has network state setup")
    check(game.has_method("_on_network_peer_joined"), "Game has peer-join handler")
    check(game.has_method("_on_network_peer_left"), "Game has peer-leave handler")
    check(game.has_method("receive_network_snapshot_batch"), "Game has snapshot receiver")
    check(game.has_method("network_spawn_player"), "Game has remote-player spawn handler")

    check(game.get("network_players") is Dictionary, "Remote-player registry is available")
    check(game.get("network_spawn_indices") is Dictionary, "Spawn-index registry is available")
    check(game.get("network_bots") is Dictionary, "Bot-replica registry is available")
    check(game.get("actors") is Array, "Actor registry is available")

    if is_instance_valid(game):
        game.queue_free()
        await process_frame

    _finish()

func _finish() -> void:
    print("ALMARAKAH MULTIPLAYER LIFECYCLE TESTS: ", checks, " checks, ", failures, " failures")
    quit(1 if failures > 0 else 0)
