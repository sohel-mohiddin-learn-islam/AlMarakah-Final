extends SceneTree

func _init():
print("=== HUMANOID RETARGET API DETAIL ===")

var profile = SkeletonProfileHumanoid.new()

print("PROFILE_CLASS: ", profile.get_class())
print("PROFILE_SCRIPT: ", profile.get_script())

print("--- SkeletonProfile properties ---")
for p in SkeletonProfileHumanoid.get_property_list():
print("PROPERTY: ", p.name, " | TYPE: ", p.type, " | USAGE: ", p.usage)

print("--- SkeletonProfileHumanoid methods ---")
for m in SkeletonProfileHumanoid.get_method_list():
print("METHOD: ", m.name)

print("--- BoneMap methods ---")
for m in BoneMap.get_method_list():
print("BONEMAP_METHOD: ", m.name)

print("--- SkeletonModifier3D methods ---")
for m in SkeletonModifier3D.get_method_list():
print("MODIFIER_METHOD: ", m.name)

print("=== END HUMANOID RETARGET API DETAIL ===")
quit()
