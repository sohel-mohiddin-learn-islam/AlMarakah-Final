extends SceneTree

func _init():
	print("=== HUMANOID RETARGET API DETAIL ===")

	print("SkeletonProfileHumanoid class: ", ClassDB.class_exists("SkeletonProfileHumanoid"))
	print("SkeletonProfile class: ", ClassDB.class_exists("SkeletonProfile"))
	print("BoneMap class: ", ClassDB.class_exists("BoneMap"))
	print("SkeletonModifier3D class: ", ClassDB.class_exists("SkeletonModifier3D"))

	print("--- SkeletonProfileHumanoid methods ---")
	for method in ClassDB.class_get_method_list("SkeletonProfileHumanoid"):
		print("METHOD: ", method.name)

	print("--- SkeletonProfileHumanoid properties ---")
	for property in ClassDB.class_get_property_list("SkeletonProfileHumanoid"):
		print("PROPERTY: ", property.name)

	print("--- BoneMap methods ---")
	for method in ClassDB.class_get_method_list("BoneMap"):
		print("BONEMAP_METHOD: ", method.name)

	print("--- BoneMap properties ---")
	for property in ClassDB.class_get_property_list("BoneMap"):
		print("BONEMAP_PROPERTY: ", property.name)

	print("--- SkeletonModifier3D methods ---")
	for method in ClassDB.class_get_method_list("SkeletonModifier3D"):
		print("MODIFIER_METHOD: ", method.name)

	print("=== END HUMANOID RETARGET API DETAIL ===")
	quit()
