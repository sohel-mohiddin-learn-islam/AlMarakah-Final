extends SceneTree

func _init():
var scene = load("res://assets/characters/quaternius/male/Superhero_Male_FullBody.gltf")

if scene == null:
print("CHARACTER_INSPECT: LOAD_FAILED")
quit(1)
return

var instance = scene.instantiate()

print("=== ALMARAKAH CHARACTER INSPECT ===")
print("ROOT: ", instance.name)
_print_tree(instance, 0)
print("=== END CHARACTER INSPECT ===")

instance.free()
quit()

func _print_tree(node: Node, depth: int) -> void:
print("%s%s [%s]" % ["  ".repeat(depth), node.name, node.get_class()])

for child in node.get_children():
_print_tree(child, depth + 1)
