extends SceneTree

func _initialize() -> void:
    print("=== DEDICATED SERVER ENTRY CHECK ===")
    var server_script: Script = load("res://scripts/dedicated_server.gd")
    if server_script == null:
        print("ENTRY CHECK: FAILED - script could not load")
        quit(1)
        return
    if not server_script.can_instantiate():
        print("ENTRY CHECK: FAILED - script cannot instantiate")
        quit(1)
        return
    print("ENTRY CHECK: PASSED")
    quit(0)
