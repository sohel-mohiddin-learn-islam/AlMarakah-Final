extends SceneTree

var output := ""

func _init():
	var scene = load("res://assets/characters/quaternius/male/Superhero_Male_FullBody.gltf")

	if scene == null:
		print("CHARACTER_INSPECT: LOAD_FAILED")
		quit(1)
		return

	var instance = scene.instantiate()
	output += "=== ALMARAKAH CHARACTER INSPECT ===\n"
	output += "ROOT: %s\n" % instance.name
	_print_tree(instance, 0)
	output += "=== END CHARACTER INSPECT ===\n"
	print(output)

	var file = FileAccess.open("character-inspection.txt", FileAccess.WRITE)
	if file:
		file.store_string(output)
		file.close()

	instance.free()
	quit()

func _print_tree(node: Node, depth: int) -> void:
	output += "%s%s [%s]\n" % ["  ".repeat(depth), node.name, node.get_class()]

	for child in node.get_children():
		_print_tree(child, depth + 1)
