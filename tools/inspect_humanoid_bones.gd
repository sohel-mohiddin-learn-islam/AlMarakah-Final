extends SceneTree

func _init():
	print("=== GODOT HUMANOID PROFILE BONES ===")
	var profile = SkeletonProfileHumanoid.new()

	print("ROOT_BONE: ", profile.get_root_bone())
	print("BONE_SIZE: ", profile.get_bone_size())

	var bone_count = profile.get_bone_size()
	for bone_index in range(bone_count):
		var bone_name = profile.get_bone_name(bone_index)
		print("BONE: ", bone_index, " = ", bone_name)

	print("=== END GODOT HUMANOID PROFILE BONES ===")
	quit()
