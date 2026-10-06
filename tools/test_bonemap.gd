extends SceneTree

func _init():
	print("=== GODOT BONEMAP TEST ===")

	var profile = SkeletonProfileHumanoid.new()
	var bone_map = BoneMap.new()

	bone_map.set_profile(profile)

	print("PROFILE_SET: ", bone_map.get_profile() != null)
	print("HIPS_PROFILE_NAME: ", profile.get_bone_name(1))
	print("SPINE_PROFILE_NAME: ", profile.get_bone_name(2))
	print("HEAD_PROFILE_NAME: ", profile.get_bone_name(6))

	bone_map.set_skeleton_bone_name("Hips", "pelvis")
	bone_map.set_skeleton_bone_name("Spine", "spine_01")
	bone_map.set_skeleton_bone_name("Head", "Head")

	print("HIPS_MAP: ", bone_map.get_skeleton_bone_name("Hips"))
	print("SPINE_MAP: ", bone_map.get_skeleton_bone_name("Spine"))
	print("HEAD_MAP: ", bone_map.get_skeleton_bone_name("Head"))

	print("=== END GODOT BONEMAP TEST ===")
	quit()
