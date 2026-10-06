extends SceneTree

func _init():
    print("=== RETARGET MODIFIER API ===")

    for method in ClassDB.class_get_method_list("RetargetModifier3D"):
        print("METHOD: ", method)

    for property in ClassDB.class_get_property_list("RetargetModifier3D"):
        print("PROPERTY: ", property)

    print("=== END RETARGET MODIFIER API ===")
    quit()
