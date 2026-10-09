extends SceneTree

const NetworkManagerScript = preload("res://scripts/network_manager.gd")

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

    manager = NetworkManagerScript.new()
    root.add_child.call_deferred(manager)

    call_deferred("_start_server")

func _start_server() -> void:
    var result: int = manager.host(port)
    if result != OK:
        push_error("ENET SERVER START FAILED: %d" % result)
        quit(1)
        return

    print("ENET SERVER LISTENING ON PORT ", port)
    print("SERVER STATUS: READY")

    heartbeat_timer = Timer.new()
    heartbeat_timer.wait_time = 10.0
    heartbeat_timer.timeout.connect(_on_heartbeat)
    root.add_child(heartbeat_timer)
    heartbeat_timer.start()

func _on_heartbeat() -> void:
    if manager != null:
        print("SERVER HEARTBEAT: connected_peers=", manager.multiplayer.get_peers().size())
