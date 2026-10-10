extends SceneTree

var manager: Node
var port: int = 7777
var heartbeat_timer: Timer

func _initialize() -> void:
    print("=== ALMARAKAH DEDICATED SERVER ===")
    print("Godot: ", Engine.get_version_info().get("string", "unknown"))

    var args: PackedStringArray = OS.get_cmdline_user_args()
    var i: int = 0
    while i < args.size():
        if args[i] == "--port" and i + 1 < args.size():
            port = int(args[i + 1])
            i += 1
        i += 1

    call_deferred("_start_server")

func _start_server() -> void:
    manager = root.get_node_or_null("NetworkManager")
    if manager == null:
        push_error("NETWORK MANAGER AUTOLOAD NOT FOUND")
        quit(1)
        return

    var result: int = manager.host(port)
    if result != OK:
        push_error("ENET SERVER START FAILED: %d" % result)
        quit(1)
        return

    var packed_scene: PackedScene = load("res://scenes/main.tscn")
    if packed_scene == null:
        push_error("MAIN GAME SCENE COULD NOT BE LOADED")
        quit(1)
        return

    var game_scene: Node = packed_scene.instantiate()
    game_scene.set("dedicated_server_mode", true)
    root.add_child(game_scene)

    print("ENET SERVER LISTENING ON PORT ", port)
    print("SERVER GAME SCENE: LOADED")
    print("SERVER STATUS: READY")

    heartbeat_timer = Timer.new()
    heartbeat_timer.wait_time = 10.0
    heartbeat_timer.timeout.connect(_on_heartbeat)
    root.add_child(heartbeat_timer)
    heartbeat_timer.start()

func _on_heartbeat() -> void:
    if manager != null:
        print("SERVER HEARTBEAT: connected_peers=", manager.multiplayer.get_peers().size())
