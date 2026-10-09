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

    check(game.has_method("network_spawn_player"), "Remote-player spawn handler exists")
    check(game.has_method("network_remove_player"), "Remote-player removal handler exists")
    check(game.has_method("receive_network_snapshot_batch"), "Snapshot receiver exists")
	check(game.has_method("_send_network_snapshot_batch"), "Snapshot sender exists")

    var players = game.get("network_players")
    var actors = game.get("actors")
    var world = game.get("world")

    check(players is Dictionary, "Remote-player registry exists")
    check(actors is Array, "Actor registry exists")
    check(world is Node3D, "Game world exists")

    if not (players is Dictionary and actors is Array and world is Node3D):
        game.queue_free()
        await process_frame
        _finish()
        return

    var local_peer_id: int = root.get_multiplayer().get_unique_id()
    var test_peer_id: int = 424242
    if test_peer_id == local_peer_id:
        test_peer_id = 424243

    game.set("networked_match", true)
    game.call("network_spawn_player", test_peer_id, Vector3(10.0, 0.0, 10.0))

    var remote_player: Node = players.get(test_peer_id)
    check(remote_player != null, "Remote player is registered")
    check(remote_player != null and actors.has(remote_player), "Remote player is in actor registry")

    if remote_player != null:
        remote_player.set("network_position", Vector3(30.0, 0.0, 30.0))
        remote_player.set("network_velocity", Vector3(2.0, 0.0, 0.0))
        remote_player.set("network_yaw", 0.75)
        remote_player.set("network_pitch", 0.25)
        remote_player.set("network_alive", true)
        remote_player.set("network_movement_amount", 1.0)
        remote_player.set("network_aiming", false)
        remote_player.set("network_sprinting", true)
        remote_player.set("network_grounded", true)

        check(remote_player.get("network_position") == Vector3(30.0, 0.0, 30.0), "Snapshot position field stores updates")
        check(remote_player.get("network_velocity") == Vector3(2.0, 0.0, 0.0), "Snapshot velocity field stores updates")
        check(is_equal_approx(float(remote_player.get("network_yaw")), 0.75), "Snapshot yaw field stores updates")
        check(is_equal_approx(float(remote_player.get("network_pitch")), 0.25), "Snapshot pitch field stores updates")
        check(bool(remote_player.get("network_alive")), "Snapshot alive field stores updates")
        check(bool(remote_player.get("network_sprinting")), "Snapshot sprint field stores updates")
        check(bool(remote_player.get("network_grounded")), "Snapshot grounded field stores updates")

        game.call("network_spawn_player", test_peer_id, Vector3(20.0, 0.0, 20.0))
        check(players.get(test_peer_id) == remote_player, "Duplicate spawn preserves the original player")
        check(actors.count(remote_player) == 1, "Duplicate spawn does not duplicate the actor")

        game.call("network_remove_player", test_peer_id)
        check(not players.has(test_peer_id), "Removed peer leaves player registry")
        check(not actors.has(remote_player), "Removed peer leaves actor registry")

        await process_frame
        check(not is_instance_valid(remote_player), "Removed remote player is freed")

    game.set("networked_match", false)
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    print("ALMARAKAH MULTIPLAYER LIFECYCLE TESTS: ", checks, " checks, ", failures, " failures")
    quit(1 if failures > 0 else 0)
