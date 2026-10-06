extends SceneTree

func _init():
	print("=== GODOT RETARGET API ===")
	print("SkeletonProfileHumanoid: ", ClassDB.class_exists("SkeletonProfileHumanoid"))
	print("SkeletonProfile: ", ClassDB.class_exists("SkeletonProfile"))
	print("BoneMap: ", ClassDB.class_exists("BoneMap"))
	print("SkeletonModifier3D: ", ClassDB.class_exists("SkeletonModifier3D"))
	print("AnimationTree: ", ClassDB.class_exists("AnimationTree"))
	print("AnimationPlayer: ", ClassDB.class_exists("AnimationPlayer"))
	print("=== END RETARGET API ===")
	quit()
