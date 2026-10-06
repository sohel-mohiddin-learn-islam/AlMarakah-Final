extends SceneTree

func _init():
print("=== RETARGET MODIFIER PROPERTIES ===")

for property in ClassDB.class_get_property_list("RetargetModifier3D"):
print("PROPERTY: ", property)

print("=== RETARGET MODIFIER CONSTANTS ===")
for constant in ClassDB.class_get_integer_constant_list("RetargetModifier3D"):
print("CONSTANT: ", constant, " = ", ClassDB.class_get_integer_constant("RetargetModifier3D", constant))

print("=== END RETARGET MODIFIER PROPERTIES ===")
quit()
