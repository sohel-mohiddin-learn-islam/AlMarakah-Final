extends SceneTree

func _init():
    print("=== RETARGET MODIFIER API ===")
    for m in ClassDB.class_get_method_list("RetargetModifier3D"):
        print(m)
    for p in ClassDB.class_get_property_list("RetargetModifier3D"):
        print("PROPERTY: ", p)
    print("=== END RETARGET MODIFIER API ===")
    quit()
