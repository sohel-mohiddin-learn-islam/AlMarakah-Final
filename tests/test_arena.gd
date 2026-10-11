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

    if failures == 0:
        print("ALMARAKAH ARENA TESTS: %d checks, 0 failures" % checks)
    else:
        push_error("ALMARAKAH ARENA TESTS: %d checks, %d failures" % [checks, failures])

    quit(1 if failures > 0 else 0)


func _test_map(map_id: int) -> void:
    var arena = Arena.new()
    root.add_child(arena)
    arena.build(map_id, false)
    await process_frame

    var terrain = arena.get_node_or_null("ContinuousTerrain") as MeshInstance3D
    var ground = arena.get_node_or_null("TerrainCollision") as StaticBody3D

    check(terrain != null, "Map %d has a terrain mesh" % map_id)
    check(terrain != null and terrain.mesh != null and terrain.mesh.get_surface_count() > 0,
        "Map %d terrain mesh has a surface" % map_id)
    check(ground != null, "Map %d has a ground collision body" % map_id)

    var collider: CollisionShape3D = null
    if ground != null:
        collider = ground.get_node_or_null("TerrainCollisionShape") as CollisionShape3D

    print("COLLISION DIAGNOSTIC map=", map_id)
    print("  terrain_exists=", terrain != null)
    if terrain != null and terrain.mesh != null:
        print("  terrain_surfaces=", terrain.mesh.get_surface_count())
        print("  terrain_vertices=", terrain.mesh.surface_get_array_len(0) if terrain.mesh.get_surface_count() > 0 else 0)
    print("  ground_exists=", ground != null)
    if ground != null:
        print("  ground_child_count=", ground.get_child_count())
        for child in ground.get_children():
            print("  ground_child_name=", child.name, " type=", child.get_class())
    print("  collider_exists=", collider != null)
    if collider != null:
        print("  shape_is_null=", collider.shape == null)
        print("  shape_type=", "null" if collider.shape == null else collider.shape.get_class())

    check(collider != null and collider.shape != null,
        "Map %d has a valid terrain collision shape" % map_id)

    var test_body := RigidBody3D.new()
    test_body.name = "TemporaryGroundTestBody"
    test_body.position = Vector3(0.0, 8.0, 0.0)
    test_body.collision_layer = 2
    test_body.collision_mask = 1
    test_body.gravity_scale = 1.0

    var test_collider := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 0.5
    test_collider.shape = sphere
    test_body.add_child(test_collider)
    root.add_child(test_body)

    for frame in range(120):
        await physics_frame

    check(test_body.global_position.y > -2.0,
        "Map %d catches a falling physics body (final Y: %.2f)" %
        [map_id, test_body.global_position.y])

    test_body.queue_free()
    arena.queue_free()
    await process_frame
