extends SceneTree

const PALACE_PATH = "res://assets/arabian_palace.glb"

var mesh_count := 0
var surface_count := 0
var vertex_count := 0
var triangle_count := 0
var collision_node_count := 0
var node_type_counts: Dictionary = {}
var material_counts: Dictionary = {}
var world_bounds := AABB()
var has_world_bounds := false


func _initialize() -> void:
    call_deferred("_inspect")


func _inspect() -> void:
    print("")
    print("========== PALACE INTERIOR DIAGNOSTIC ==========")
    print("ASSET: ", PALACE_PATH)

    if not ResourceLoader.exists(PALACE_PATH):
        push_error("Palace GLB resource not found.")
        quit(1)
        return

    var packed := load(PALACE_PATH) as PackedScene
    if packed == null:
        push_error("Palace GLB could not be loaded as PackedScene.")
        quit(1)
        return

    var palace := packed.instantiate()
    if palace == null:
        push_error("Palace scene instantiation failed.")
        quit(1)
        return

    root.add_child(palace)
    await process_frame

    _visit(palace)

    print("LOAD_RESULT: SUCCESS")
    print("MESH_INSTANCES: ", mesh_count)
    print("MESH_SURFACES: ", surface_count)
    print("VERTICES: ", vertex_count)
    print("ESTIMATED_TRIANGLES: ", triangle_count)
    print("COLLISION_NODES: ", collision_node_count)

    if has_world_bounds:
        print("WORLD_BOUNDS_POSITION: ", world_bounds.position)
        print("WORLD_BOUNDS_SIZE: ", world_bounds.size)
        print("WORLD_BOUNDS_END: ", world_bounds.end)
    else:
        print("WORLD_BOUNDS: unavailable")

    print("NODE_TYPES:")
    for key in node_type_counts:
        print("  ", key, " = ", node_type_counts[key])

    print("MATERIALS:")
    for key in material_counts:
        print("  ", key, " = ", material_counts[key])

    print("========== END PALACE INTERIOR DIAGNOSTIC ==========")

    palace.free()
    quit(0)


func _visit(node: Node) -> void:
    var node_type := node.get_class()
    node_type_counts[node_type] = node_type_counts.get(node_type, 0) + 1

    if node is CollisionObject3D or node is CollisionShape3D or node is CollisionPolygon3D:
        collision_node_count += 1

    if node is MeshInstance3D:
        var instance := node as MeshInstance3D
        var mesh := instance.mesh

        if mesh != null:
            mesh_count += 1
            surface_count += mesh.get_surface_count()

            for surface_index in range(mesh.get_surface_count()):
                var arrays := mesh.surface_get_arrays(surface_index)

                if arrays.size() > Mesh.ARRAY_VERTEX:
                    var vertices = arrays[Mesh.ARRAY_VERTEX]
                    if vertices is PackedVector3Array:
                        vertex_count += vertices.size()
                        if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
                            triangle_count += int(arrays[Mesh.ARRAY_INDEX].size() / 3)
                        else:
                            triangle_count += int(vertices.size() / 3)

                var material := instance.get_active_material(surface_index)
                if material == null:
                    material = mesh.surface_get_material(surface_index)

                if material != null:
                    var material_name := material.resource_name
                    if material_name.is_empty():
                        material_name = material.get_class()
                    material_counts[material_name] = material_counts.get(material_name, 0) + 1

            var local_bounds := mesh.get_aabb()
            var global_transform := instance.global_transform
            var transformed_bounds := _transform_aabb(local_bounds, global_transform)

            if not has_world_bounds:
                world_bounds = transformed_bounds
                has_world_bounds = true
            else:
                world_bounds = world_bounds.merge(transformed_bounds)

    for child in node.get_children():
        _visit(child)


func _transform_aabb(source: AABB, transform: Transform3D) -> AABB:
    var result := AABB()
    var first := true

    for x in [source.position.x, source.end.x]:
        for y in [source.position.y, source.end.y]:
            for z in [source.position.z, source.end.z]:
                var point := transform * Vector3(x, y, z)

                if first:
                    result = AABB(point, Vector3.ZERO)
                    first = false
                else:
                    result = result.expand(point)

    return result
