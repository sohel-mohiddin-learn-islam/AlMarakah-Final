extends SceneTree

func _init():
	var scene = load("res://assets/animations/quaternius/AnimationLibrary_Godot_Standard.gltf")
	if scene == null:
		print("ANIMATION_INSPECT: LOAD_FAILED")
		quit(1)
		return
	var instance = scene.instantiate()
	print("=== ALMARAKAH ANIMATION INSPECT ===")
	print("ROOT: %s [%s]" % [instance.name, instance.get_class()])
	_print_tree(instance, 0)
	_print_animations(instance)
	print("=== END ANIMATION INSPECT ===")
	instance.free()
	quit()

func _print_tree(node: Node, depth: int) -> void:
	print("%s%s [%s]" % ["  ".repeat(depth), node.name, node.get_class()])
	for child in node.get_children():
		_print_tree(child, depth + 1)

func _print_animations(node: Node) -> void:
	if node is AnimationPlayer:
		print("ANIMATION_PLAYER: %s" % node.get_path())
		var library = node.get_animation_library("")
		if library:
			for animation_name in library.get_animation_list():
				print("ANIMATION: %s" % animation_name)
	for child in node.get_children():
		_print_animations(child)
