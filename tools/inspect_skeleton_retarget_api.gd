extends SceneTree

func _init():
    print("=== SKELETON RETARGET API ===")

    var methods = ClassDB.class_get_method_list("Skeleton3D")
    for method in methods:
        var n = str(method.get("name", ""))
        if "retarget" in n.to_lower() or "profile" in n.to_lower() or "bone" in n.to_lower():
            print("METHOD: ", method)

    print("=== SKELETON PROPERTIES ===")
    var properties = ClassDB.class_get_property_list("Skeleton3D")
    for property in properties:
        var n = str(property.get("name", ""))
        if "retarget" in n.to_lower() or "profile" in n.to_lower() or "bone" in n.to_lower():
            print("PROPERTY: ", property)

    print("=== END SKELETON RETARGET API ===")
    quit()
