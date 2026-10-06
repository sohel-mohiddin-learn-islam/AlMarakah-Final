extends SceneTree

func _init():
	print("=== GODOT HUMANOID PROFILE BONES ===")
	var profile = SkeletonProfileHumanoid.new()
	print("ROOT_BONE: ", profile.get_root_bone())
	print("GROUP_SIZE: ", profile.get_group_size())

	for group_index in range(profile.get_group_size()):
		var group_name = profile.get_group_name(group_index)
		print("GROUP: ", group_index, " = ", group_name)
		var bone_count = profile.get_bone_size(group_index)
		print("BONE_COUNT: ", bone_count)
		for bone_index in range(bone_count):
			var bone_name = profile.get_bone_name(group_index, bone_index)
			print("BONE: ", group_index, "/", bone_index, " = ", bone_name)

	print("=== END GODOT HUMANOID PROFILE BONES ===")
	quit()
