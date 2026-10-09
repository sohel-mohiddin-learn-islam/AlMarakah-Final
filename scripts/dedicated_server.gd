extends SceneTree

const NetworkManagerScript = preload("res://scripts/network_manager.gd")

var manager: Node
var port: int = 7777
var heartbeat: float = 0.0

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
    root.add_child(manager)
    var result: int = manager.host(port)
    if result != OK:
        push_error("ENET SERVER START FAILED: %d" % result)
        quit(1)
        return
    print("ENET SERVER LISTENING ON PORT ", port)
    print("SERVER STATUS: READY")
    set_process(true)

func _process(delta: float) -> bool:
    heartbeat += delta
    if heartbeat >= 10.0:
        heartbeat = 0.0
        print("SERVER HEARTBEAT: connected_peers=", manager.multiplayer.get_peers().size())
    return false
