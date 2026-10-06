extends SceneTree

func _init():
    print("=== RETARGET MODIFIER PROPERTIES ===")

    var properties = ClassDB.class_get_property_list("RetargetModifier3D")

    for property in properties:
        print("PROPERTY: ", property)

    print("=== RETARGET MODIFIER CONSTANTS ===")

    var constants = ClassDB.class_get_integer_constant_list("RetargetModifier3D")

    for constant in constants:
        print("CONSTANT: ", constant, " = ", ClassDB.class_get_integer_constant("RetargetModifier3D", constant))

    print("=== END RETARGET MODIFIER PROPERTIES ===")
    quit()
