extends Node3D
## Custom, mobile-friendly Royal Fortress Palace.
## All structural walls use simple matching visual and collision boxes.

var _materials: Dictionary = {}


func _ready() -> void:
    _build_palace()


func _build_palace() -> void:
    var sand := Color("#cba477")
    var light_stone := Color("#ead2a5")
    var dark_stone := Color("#98704c")
    var gold := Color("#c99a42")
    var wood := Color("#67432f")
    var dark := Color("#343a3b")
    var water := Color("#399ba8")

    # Continuous, level courtyard floor.
    _box("PalaceFoundation", Vector3(0, -0.13, 0),
        Vector3(28, 0.26, 23), sand)

    # Outer fortress walls. The southern entrance remains completely open.
    _box("WestFortressWall", Vector3(-13.3, 2.3, 0),
        Vector3(1.0, 4.6, 22), sand)
    _box("EastFortressWall", Vector3(13.3, 2.3, 0),
        Vector3(1.0, 4.6, 22), sand)
    _box("NorthFortressWall", Vector3(0, 2.3, -10.8),
        Vector3(27, 4.6, 1.0), sand)

    # Front wall segments leave an 8-metre-wide entrance.
    _box("FrontWallWest", Vector3(-9, 2.3, 10.8),
        Vector3(9, 4.6, 1.0), sand)
    _box("FrontWallEast", Vector3(9, 2.3, 10.8),
        Vector3(9, 4.6, 1.0), sand)

    # Monumental open gateway.
    for side in [-1.0, 1.0]:
        _box("GatewayPillar", Vector3(side * 3.65, 2.1, 10.7),
            Vector3(0.65, 4.2, 1.35), light_stone)
        _box("GatewayBase", Vector3(side * 3.65, 0.3, 10.65),
            Vector3(1.0, 0.6, 1.55), gold)
        _box("GatewayCapital", Vector3(side * 3.65, 4.25, 10.7),
            Vector3(1.0, 0.3, 1.5), gold)

    _box("GatewayLintel", Vector3(0, 4.25, 10.7),
        Vector3(7.9, 0.65, 1.4), light_stone)
    _box("GatewayCrownLower", Vector3(0, 4.75, 10.7),
        Vector3(6.6, 0.25, 1.25), gold)
    _box("GatewayCrownUpper", Vector3(0, 5.05, 10.7),
        Vector3(4.8, 0.25, 1.0), light_stone)
    _box("GatewayCrownTop", Vector3(0, 5.32, 10.7),
        Vector3(2.8, 0.3, 0.8), gold)

    # Four defensive towers.
    for x in [-12.8, 12.8]:
        for z in [-10.5, 10.5]:
            _tower(Vector3(x, 0, z), sand, light_stone, gold)

    # Stone coping and battlements along the fortress perimeter.
    for x in range(-11, 12, 2):
        _box("NorthBattlement", Vector3(float(x), 4.9, -10.8),
            Vector3(0.9, 0.6, 1.05), light_stone)

    for side in [-1.0, 1.0]:
        for z in range(-9, 10, 2):
            _box("SideBattlement",
                Vector3(side * 13.3, 4.9, float(z)),
                Vector3(1.05, 0.6, 0.9), light_stone)

    for x in range(-12, 13, 3):
        _box("NorthWallTrim", Vector3(float(x), 4.45, -10.22),
            Vector3(2.5, 0.16, 0.12), gold)
        _box("SouthWallTrim", Vector3(float(x), 4.45, 10.22),
            Vector3(2.5, 0.16, 0.12), gold)

    # Recessed-looking decorative panels on the outer walls.
    for side in [-1.0, 1.0]:
        for z in [-7.0, -3.5, 0.0, 3.5, 7.0]:
            _box("WallPanel", Vector3(side * 13.84, 2.4, z),
                Vector3(0.07, 1.8, 1.35), dark_stone, false)
            _box("WallPanelInset", Vector3(side * 13.91, 2.4, z),
                Vector3(0.06, 1.45, 0.95), light_stone, false)

    # Royal throne hall at the northern end of the courtyard.
    # Its front wall has a central opening for entry.
    _box("ThroneHallWestWall", Vector3(-6.8, 2.7, -6.9),
        Vector3(0.65, 5.4, 7.0), sand)
    _box("ThroneHallEastWall", Vector3(6.8, 2.7, -6.9),
        Vector3(0.65, 5.4, 7.0), sand)
    _box("ThroneHallRearWall", Vector3(0, 2.7, -10.0),
        Vector3(13.6, 5.4, 0.65), sand)

    # Open central hall doorway, four metres wide.
    _box("HallFrontWest", Vector3(-4.5, 2.7, -3.45),
        Vector3(4.5, 5.4, 0.65), sand)
    _box("HallFrontEast", Vector3(4.5, 2.7, -3.45),
        Vector3(4.5, 5.4, 0.65), sand)
    _box("HallDoorLintel", Vector3(0, 5.0, -3.45),
        Vector3(4.2, 0.8, 0.9), light_stone)
    _box("HallDoorGoldBand", Vector3(0, 5.45, -3.42),
        Vector3(4.7, 0.15, 1.0), gold)

    # Interior floor and royal dais.
    _box("ThroneHallFloor", Vector3(0, 0.015, -7.0),
        Vector3(12.6, 0.06, 6.0), light_stone)
    _box("ThroneDaisLower", Vector3(0, 0.25, -8.6),
        Vector3(5.4, 0.45, 1.8), dark_stone)
    _box("ThroneDaisUpper", Vector3(0, 0.55, -8.6),
        Vector3(4.4, 0.2, 1.4), gold)
    # Eight broad royal steps leading to the raised throne dais.
    # Visual treads are paired with one continuous walkable ramp collider.
    for i in range(8):
        var step_top: float = float(i + 1) * 0.075
        var step_z: float = -5.65 - float(i) * 0.28

        _box("ThroneApproachStep",
            Vector3(0.0, step_top - 0.04, step_z),
            Vector3(3.8, 0.08, 0.36), light_stone, false)

        _box("ThroneStepGoldEdge",
            Vector3(0.0, step_top - 0.012, step_z + 0.16),
            Vector3(3.8, 0.024, 0.035), gold, false)

    var throne_ramp_body := StaticBody3D.new()
    throne_ramp_body.name = "ThroneStairRampCollision"
    throne_ramp_body.position = Vector3(0.0, 0.26, -6.63)
    throne_ramp_body.rotation.x = atan(0.6 / 2.6)

    var throne_ramp_shape := BoxShape3D.new()
    throne_ramp_shape.size = Vector3(3.7, 0.18, 2.68)

    var throne_ramp_collider := CollisionShape3D.new()
    throne_ramp_collider.name = "ThroneStairRampShape"
    throne_ramp_collider.shape = throne_ramp_shape
    throne_ramp_body.add_child(throne_ramp_collider)
    add_child(throne_ramp_body)

    _box("RoyalThroneBack", Vector3(0, 1.55, -9.1),
        Vector3(2.2, 2.0, 0.35), wood)
    _box("RoyalThroneSeat", Vector3(0, 0.95, -8.55),
        Vector3(2.4, 0.3, 1.2), wood)

    # Hall columns, with decorative capitals.
    for x in [-4.8, -2.5, 2.5, 4.8]:
        for z in [-8.8, -5.3]:
            _box("HallColumn", Vector3(x, 2.15, z),
                Vector3(0.48, 4.3, 0.48), light_stone)
            _box("HallColumnBase", Vector3(x, 0.2, z),
                Vector3(0.8, 0.4, 0.8), gold)
            _box("HallColumnCapital", Vector3(x, 4.35, z),
                Vector3(0.75, 0.3, 0.75), gold)

    # Open side chambers beside the throne hall.
    for side in [-1.0, 1.0]:
        var room_x: float = side * 9.4
        _box("RoyalSideChamberFloor",
            Vector3(room_x, 0.02, -5.2),
            Vector3(5.0, 0.08, 6.5), light_stone)
        _box("RoyalSideChamberBack",
            Vector3(room_x, 1.8, -8.4),
            Vector3(5.0, 3.6, 0.3), sand)
        _box("RoyalSideChamberOuter",
            Vector3(side * 11.8, 1.8, -5.2),
            Vector3(0.3, 3.6, 6.5), sand)
        _box("RoyalSideChamberFrontLeft",
            Vector3(room_x - side * 2.0, 1.8, -2.0),
            Vector3(1.0, 3.6, 0.3), sand)
        _box("RoyalSideChamberFrontRight",
            Vector3(room_x + side * 2.0, 1.8, -2.0),
            Vector3(1.0, 3.6, 0.3), sand)
        _box("ChamberRoofTrim", Vector3(room_x, 3.7, -5.2),
            Vector3(5.4, 0.25, 7.0), gold, false)

    # Gallery steps remain visible; a continuous ramp provides walkable collision.
    for i in range(10):
        var height: float = float(i + 1) * 0.32
        var z: float = 5.4 - float(i) * 0.8
        _box("GalleryStair", Vector3(-9.0, height * 0.5, z),
            Vector3(3.0, height, 0.95), light_stone, false)

    var ramp_body := StaticBody3D.new()
    ramp_body.name = "GalleryStairRampCollision"
    ramp_body.position = Vector3(-10.0, 1.60, 2.0)
    ramp_body.rotation.x = atan(3.2 / 8.6)

    var ramp_shape := BoxShape3D.new()
    ramp_shape.size = Vector3(1.8, 0.22, 8.75)

    var ramp_collider := CollisionShape3D.new()
    ramp_collider.name = "GalleryStairRampShape"
    ramp_collider.shape = ramp_shape
    ramp_body.add_child(ramp_collider)
    add_child(ramp_body)

    _box("GalleryLanding", Vector3(-9.0, 3.18, -3.0),
        Vector3(4.0, 0.3, 3.5), light_stone)
    _box("UpperGalleryWalkway", Vector3(-10.0, 3.18, 2.0),
        Vector3(2.2, 0.3, 9.0), light_stone)
    _box("GalleryRailInner", Vector3(-8.8, 3.8, 2.0),
        Vector3(0.16, 1.0, 9.0), gold)
    _box("GalleryRailEnd", Vector3(-10.0, 3.8, 6.4),
        Vector3(2.2, 1.0, 0.16), gold)

    # Central courtyard fountain: low enough to walk around.
    _box("FountainSouthRim", Vector3(0, 0.3, 1.0),
        Vector3(4.2, 0.6, 0.35), light_stone)
    _box("FountainNorthRim", Vector3(0, 0.3, -1.0),
        Vector3(4.2, 0.6, 0.35), light_stone)
    _box("FountainWestRim", Vector3(-1.95, 0.3, 0),
        Vector3(0.35, 0.6, 2.0), light_stone)
    _box("FountainEastRim", Vector3(1.95, 0.3, 0),
        Vector3(0.35, 0.6, 2.0), light_stone)
    _box("FountainWater", Vector3(0, 0.22, 0),
        Vector3(3.55, 0.08, 1.65), water, false)
    _box("FountainPedestal", Vector3(0, 0.65, 0),
        Vector3(0.65, 0.7, 0.65), gold, false)

    # Courtyard paving bands and gold inlays.
    for x in range(-10, 11, 2):
        _box("CourtyardPavingBand", Vector3(float(x), 0.012, 4.0),
            Vector3(0.055, 0.025, 9.0), dark_stone, false)
    for z in [-9.0, -7.0, -5.0, 5.0, 7.0, 9.0]:
        _box("CourtyardPavingBand", Vector3(0, 0.014, z),
            Vector3(21.0, 0.025, 0.055), dark_stone, false)

    # Low, decorative entrance lamps. These do not block the gateway.
    for x in [-5.0, 5.0]:
        _box("EntranceLampBase", Vector3(x, 0.3, 8.0),
            Vector3(0.7, 0.6, 0.7), dark_stone)
        _box("EntranceLampBody", Vector3(x, 1.0, 8.0),
            Vector3(0.4, 0.8, 0.4), gold, false)
        _box("EntranceLampTop", Vector3(x, 1.48, 8.0),
            Vector3(0.65, 0.16, 0.65), light_stone, false)

    # Extra wall-top accents, using small mobile-friendly boxes.
    for x in range(-10, 11, 4):
        _box("HallRoofAccent", Vector3(float(x), 5.65, -10.0),
            Vector3(1.2, 0.35, 0.8), gold, false)

    _build_grand_palace_details(light_stone, dark_stone, gold)

    print("Royal Fortress Palace: custom geometry and structural collision created.")


func _build_grand_palace_details(
        stone: Color, dark_stone: Color, gold: Color) -> void:
    # Monumental front facade: decorative pieces avoid blocking the doorway.
    for side in [-1.0, 1.0]:
        _box("GrandFacadePillar",
            Vector3(side * 5.65, 2.85, -2.98),
            Vector3(0.72, 5.7, 0.72), stone)

        _box("GrandFacadePillarBase",
            Vector3(side * 5.65, 0.28, -2.98),
            Vector3(1.05, 0.45, 1.0), gold)

        _box("GrandFacadePillarCapital",
            Vector3(side * 5.65, 5.65, -2.98),
            Vector3(1.05, 0.38, 1.0), gold)

        # Tall ornamental panels flanking the central doorway.
        _box("GrandFacadePanel",
            Vector3(side * 3.35, 3.1, -3.075),
            Vector3(1.15, 3.65, 0.10), dark_stone, false)

        _box("GrandFacadePanelInset",
            Vector3(side * 3.35, 3.1, -3.14),
            Vector3(0.78, 3.1, 0.06), stone, false)

        # Stepped roof shoulders give the main hall a larger silhouette.
        _box("GrandRoofShoulder",
            Vector3(side * 4.7, 5.55, -7.0),
            Vector3(4.0, 0.32, 5.8), gold, false)

    # Wide layered crown above the main entrance.
    _box("GrandFacadeCrownLower",
        Vector3(0, 5.72, -3.0),
        Vector3(12.4, 0.32, 0.95), dark_stone, false)

    _box("GrandFacadeCrownMiddle",
        Vector3(0, 5.98, -3.0),
        Vector3(10.8, 0.22, 0.82), gold, false)

    _box("GrandFacadeCrownUpper",
        Vector3(0, 6.23, -3.0),
        Vector3(8.8, 0.24, 0.72), stone, false)

    # Gold architectural bands across the front of the royal hall.
    for side in [-1.0, 1.0]:
        _box("FacadeGoldBand",
            Vector3(side * 4.3, 4.85, -3.055),
            Vector3(2.5, 0.12, 0.08), gold, false)

    # Three domes use lightweight meshes rather than detailed imported assets.
    var dome_positions: Array[Vector3] = [
        Vector3(0, 6.05, -7.0),
        Vector3(-4.45, 5.78, -6.8),
        Vector3(4.45, 5.78, -6.8)
    ]

    var dome_scales: Array[Vector3] = [
        Vector3(2.05, 1.35, 1.8),
        Vector3(1.05, 0.78, 1.0),
        Vector3(1.05, 0.78, 1.0)
    ]

    for i in range(dome_positions.size()):
        var dome := SphereMesh.new()
        dome.radius = 1.0
        dome.height = 2.0
        dome.radial_segments = 20
        dome.rings = 12

        var dome_visual := MeshInstance3D.new()
        dome_visual.name = "RoyalDomeVisual"
        dome_visual.mesh = dome
        dome_visual.position = dome_positions[i]
        dome_visual.scale = dome_scales[i]

        var dome_material := StandardMaterial3D.new()
        dome_material.albedo_color = stone
        dome_material.roughness = 0.9
        dome_visual.material_override = dome_material
        add_child(dome_visual)

        # Gold finial above each dome.
        var finial := SphereMesh.new()
        finial.radius = 0.16 if i == 0 else 0.10
        finial.height = finial.radius * 2.0
        finial.radial_segments = 12
        finial.rings = 8

        var finial_visual := MeshInstance3D.new()
        finial_visual.name = "RoyalDomeFinial"
        finial_visual.mesh = finial
        finial_visual.position = dome_positions[i] + Vector3(
            0, dome_scales[i].y + 0.12, 0)

        var finial_material := StandardMaterial3D.new()
        finial_material.albedo_color = gold
        finial_material.metallic = 0.35
        finial_material.roughness = 0.55
        finial_visual.material_override = finial_material
        add_child(finial_visual)

    # Additional rooftop parapets and decorative merlons.
    for x in range(-5, 6, 2):
        _box("RoyalRoofMerlon",
            Vector3(float(x), 5.95, -10.15),
            Vector3(0.8, 0.55, 0.65), stone, false)

    # Repeated stone reliefs add visual rhythm to the royal facade.
    for x in [-4.7, -2.9, 2.9, 4.7]:
        _box("RoyalFacadeRelief",
            Vector3(x, 1.75, -3.075),
            Vector3(0.42, 0.72, 0.08), gold, false)

    print("Grand Palace details: facade, three domes and royal roof accents created.")


func _tower(center: Vector3, stone: Color,
        trim: Color, accent: Color) -> void:
    _box("FortressTowerBody", center + Vector3(0, 3.0, 0),
        Vector3(4.0, 6.0, 4.0), stone)
    _box("FortressTowerBelt", center + Vector3(0, 4.9, 0),
        Vector3(4.25, 0.25, 4.25), trim)
    _box("FortressTowerCrown", center + Vector3(0, 6.15, 0),
        Vector3(4.5, 0.35, 4.5), accent)

    for x in [-1.45, 0.0, 1.45]:
        for z in [-1.45, 1.45]:
            _box("TowerBattlement",
                center + Vector3(x, 6.55, z),
                Vector3(0.75, 0.55, 0.75), trim)


func _box(label: String, center: Vector3, size: Vector3,
        color: Color, solid: bool = true) -> void:
    var mesh := BoxMesh.new()
    mesh.size = size

    var visual := MeshInstance3D.new()
    visual.name = label + "Visual"
    visual.mesh = mesh
    visual.material_override = _material(color)

    if solid:
        var body := StaticBody3D.new()
        body.name = label
        body.position = center

        var shape := BoxShape3D.new()
        shape.size = size

        var collider := CollisionShape3D.new()
        collider.shape = shape
        body.add_child(collider)
        body.add_child(visual)
        add_child(body)
    else:
        visual.position = center
        add_child(visual)


func _material(color: Color) -> StandardMaterial3D:
    var key: String = color.to_html(false)
    if _materials.has(key):
        return _materials[key] as StandardMaterial3D

    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.88
    _materials[key] = material
    return material
