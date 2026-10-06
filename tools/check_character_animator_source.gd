extends SceneTree

func _init() -> void:
    print("=== DIRECT SOURCE PARSE TEST ===")

    var source_path := "res://scripts/character_animator.gd"
    var source := FileAccess.get_file_as_string(source_path)

    print("SOURCE_LENGTH: ", source.length())
    print("SOURCE_LINES: ", source.split("\n").size())

    var script := GDScript.new()
    script.source_code = source

    var result := script.reload()

    print("RELOAD_RESULT: ", result)
    print("CAN_INSTANTIATE: ", script.can_instantiate())
    print("HAS_SOURCE_CODE: ", script.has_source_code())

    quit(0 if result == OK else 1)
