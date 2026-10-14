extends SceneTree

const Arena = preload("res://scripts/arena.gd")

var checks: int = 0
var failures: int = 0


func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("FAIL: " + message)


func _initialize() -> void:
    _run.call_deferred()


func _run() -> void:
    await _test_map(0)
    await _test_map(1)
    await _test_map(2)
    await _test_wasteland_compact_dimensions()

    if failures == 0:
        print("ALMARAKAH ARENA TESTS: %d checks, 0 failures" % checks)
    else:
        push_error("ALMARAKAH ARENA TESTS: %d checks, %d failures" % [checks, failures])

    quit(1 if failures > 0 else 0)


func _test_wasteland_compact_dimensions() -> void:
    var arena = Arena.new()
    root.add_child(arena)
    arena.build(2, true)
    await process_frame
    check(is_equal_approx(arena.extent, 42.0),
        "Wasteland Clash Squad retains its compact footprint")
    check(arena.get_node_or_null("WastelandPOI_Peak") == null,
        "Compact Clash Squad does not generate Wasteland BR landmarks")
    var compact_enterable_count: int = 0
    for child in arena.get_children():
        if child.name.begins_with("WastelandEnterableBuilding_"):
            compact_enterable_count += 1
    check(compact_enterable_count == 0,
        "Compact Clash Squad retains its existing building layout")
    arena.queue_free()
    await process_frame


func _test_map(map_id: int) -> void:
    var arena = Arena.new()
    root.add_child(arena)
    arena.build(map_id, false)
    if map_id == 2:
        check(is_equal_approx(arena.extent, 960.0),
            "Wasteland BR has a 1.92 km square footprint")
    else:
        check(is_equal_approx(arena.extent, 125.0),
            "Existing full-size map dimensions remain unchanged")
    await process_frame

    if map_id == 2:
        var poi_names: Array[String] = [
            "Peak", "ClockTower", "Factory", "OldTown",
            "SandstoneCity", "MarketDistrict", "OasisVillage", "WadiSettlement",
            "DustyCrossroads", "PalmGroveVillage", "DesertFarmstead", "MilitaryCamp",
            "RadioStation", "Waterworks", "RailwayYard", "CargoDepot",
            "CanyonPass", "AbandonedQuarry", "RuinedFort", "HiddenOasis"
        ]
        for poi_index in range(poi_names.size()):
            var poi_name: String = poi_names[poi_index]
            check(arena.get_node_or_null("WastelandPOI_" + poi_name) != null,
                "Wasteland BR generates the " + poi_name + " landmark marker")
            check(arena.get_node_or_null("WastelandEnterableBuilding_Outpost_%d_Main" % poi_index) != null,
                "Wasteland " + poi_name + " has its corresponding main building")
        var enterable_count: int = 0
        for child in arena.get_children():
            if child.name.begins_with("WastelandEnterableBuilding_"):
                enterable_count += 1
        check(enterable_count >= 20,
            "Wasteland BR generates enterable main buildings at all 20 outposts")

    if map_id == 0 or map_id == 2:
        var terrain := arena.get_node_or_null("ContinuousTerrain") as MeshInstance3D
        var ground := arena.get_node_or_null("TerrainCollision") as StaticBody3D
        check(terrain != null, "Procedural map has a terrain mesh")
        check(terrain != null and terrain.mesh != null and terrain.mesh.get_surface_count() > 0,
            "Procedural map terrain has a surface")

        var vertex_count: int = -1
        if terrain != null and terrain.mesh != null and terrain.mesh.get_surface_count() > 0:
            var terrain_arrays: Array = terrain.mesh.surface_get_arrays(0)
            var terrain_vertices: PackedVector3Array = terrain_arrays[Mesh.ARRAY_VERTEX]
            vertex_count = terrain_vertices.size()
        if map_id == 2:
            check(vertex_count == 37249,
                "Wasteland BR terrain uses a 193 x 193 shared-vertex grid")
        check(ground != null, "Procedural map has a ground collision body")

        var collider: CollisionShape3D = null
        if ground != null:
            collider = ground.get_node_or_null("TerrainCollisionShape") as CollisionShape3D
        check(collider != null and collider.shape != null,
            "Procedural map has a valid terrain collision shape")
    else:
        var terraforge := arena.get_node_or_null("TerraForgeWorld") as Node3D
        check(terraforge != null, "AlMarakah instantiates the TerraForge world")

        var pending: Array[Node] = [arena]
        var mesh_count: int = 0
        var solid_collision_count: int = 0

        while not pending.is_empty():
            var current: Node = pending.pop_back()
            for child in current.get_children():
                pending.append(child)
            if current is MeshInstance3D:
                var instance := current as MeshInstance3D
                if instance.mesh != null and instance.mesh.get_surface_count() > 0:
                    mesh_count += 1
            if current is StaticBody3D and current.name != "TerraForgeBoundary":
                if current.get_child_count() > 0:
                    for body_child in current.get_children():
                        if body_child is CollisionShape3D and body_child.shape != null:
                            solid_collision_count += 1
                            break

        check(mesh_count >= 2, "TerraForge has imported visible mesh surfaces")
        check(solid_collision_count >= 2,
            "TerraForge solid terrain meshes have collision")

    var test_body := RigidBody3D.new()
    test_body.name = "TemporaryGroundTestBody"
    test_body.position = Vector3(0.0, 24.0 if map_id == 1 else 8.0, 0.0)
    test_body.collision_layer = 2
    test_body.collision_mask = 1
    test_body.gravity_scale = 1.0

    var test_collider := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 0.5
    test_collider.shape = sphere
    test_body.add_child(test_collider)
    root.add_child(test_body)

    await physics_frame
    var test_world := test_body.get_world_3d()
    if test_world != null:
        var ray_top: float = 30.0 if map_id == 1 else 20.0
        var ray_query := PhysicsRayQueryParameters3D.create(
            Vector3(0.0, ray_top, 0.0),
            Vector3(0.0, -20.0, 0.0),
            1
        )
        var ray_hit: Dictionary = test_world.direct_space_state.intersect_ray(ray_query)
        print("MAP ", map_id, " CENTER_RAY_HIT=",
            ray_hit.get("collider").name if ray_hit.has("collider") else "none")
        print("MAP ", map_id, " CENTER_RAY_POSITION=", ray_hit.get("position", Vector3.ZERO))
        var hit_is_expected_ground: bool = not ray_hit.is_empty()
        if map_id == 0 or map_id == 2:
            hit_is_expected_ground = hit_is_expected_ground and ray_hit.has("collider") and ray_hit["collider"].name == "TerrainCollision"
        check(hit_is_expected_ground,
            "Map %d center ray hits the actual ground, not the fallback floor" % map_id)
    else:
        check(false, "Map %d has an accessible physics world" % map_id)

    for frame in range(120):
        await physics_frame

    check(test_body.global_position.y > -2.0,
        "Map %d catches a falling physics body (final Y: %.2f)" %
        [map_id, test_body.global_position.y])

    test_body.queue_free()
    arena.queue_free()
    await process_frame
