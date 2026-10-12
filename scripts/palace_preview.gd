extends Node3D

@onready var palace: Node3D = $ArabianPalace
@onready var camera: Camera3D = $PreviewCamera

var target := Vector3(0.0, 3.5, 0.0)
var distance := 50.0
var yaw := 0.0
var pitch := deg_to_rad(17.0)
var dragging_mouse := false
var touches: Dictionary = {}
var previous_pinch_gap := -1.0

const MIN_DISTANCE := 12.0
const MAX_DISTANCE := 100.0
const DRAG_SENSITIVITY := 0.005
const PINCH_SENSITIVITY := 0.06

func _ready() -> void:
    _apply_materials(palace)
    _update_camera()

func _apply_materials(node: Node) -> void:
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh != null:
            for surface in range(mesh_instance.mesh.get_surface_count()):
                var source := mesh_instance.get_active_material(surface)
                if source == null:
                    source = mesh_instance.get_surface_override_material(surface)
                if source == null:
                    source = mesh_instance.mesh.surface_get_material(surface)
                if source == null:
                    continue

                var material_name := source.resource_name.strip_edges().to_lower()
                var color := _color_for_material(material_name)

                # White or unnamed materials receive a warm sandstone fallback.
                if color.a < 0.0:
                    if source is StandardMaterial3D:
                        var original := source as StandardMaterial3D
                        if original.albedo_color.r > 0.92 and original.albedo_color.g > 0.92 and original.albedo_color.b > 0.92:
                            color = Color("#c4ad8a")
                        else:
                            continue
                    else:
                        color = Color("#c4ad8a")

                var replacement := StandardMaterial3D.new()
                replacement.albedo_color = color
                replacement.roughness = 0.88

                if material_name.contains("fencing"):
                    replacement.metallic = 0.55
                    replacement.roughness = 0.62

                if material_name.contains("glass"):
                    replacement.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                    replacement.albedo_color.a = 0.45
                    replacement.roughness = 0.2

                mesh_instance.set_surface_override_material(surface, replacement)

    for child in node.get_children():
        _apply_materials(child)

func _color_for_material(material_name: String) -> Color:
    if material_name.contains("stone_brushed_khaki"):
        return Color("#c4a77b")
    if material_name.contains("stone_masonry_multi"):
        return Color("#a99170")
    if material_name == "material":
        return Color("#b99b70")
    if material_name.contains("wood"):
        return Color("#56351f")
    if material_name.contains("burnt_umber"):
        return Color("#493022")
    if material_name.contains("charcoal"):
        return Color("#343638")
    if material_name.contains("dimgray"):
        return Color("#62615d")
    if material_name.contains("lightgray"):
        return Color("#bcbab2")
    if material_name.contains("beige"):
        return Color("#c9b18a")
    if material_name.contains("concrete"):
        return Color("#a8a092")
    if material_name.contains("tile_navy"):
        return Color("#555f70")
    if material_name.contains("grass") or material_name.contains("vegetation"):
        return Color("#65734a")
    if material_name.contains("fencing"):
        return Color("#54504a")
    if material_name.contains("glass"):
        return Color("#a8c6d4")
    if material_name.contains("water"):
        return Color("#668f9b")
    return Color(-1.0, -1.0, -1.0, -1.0)

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            touches[event.index] = event.position
        else:
            touches.erase(event.index)
            previous_pinch_gap = -1.0
        return

    if event is InputEventScreenDrag:
        touches[event.index] = event.position

        if touches.size() >= 2:
            var positions: Array = touches.values()
            var gap: float = positions[0].distance_to(positions[1])
            if previous_pinch_gap >= 0.0:
                distance = clampf(
                    distance - (gap - previous_pinch_gap) * PINCH_SENSITIVITY,
                    MIN_DISTANCE,
                    MAX_DISTANCE
                )
                _update_camera()
            previous_pinch_gap = gap
        else:
            previous_pinch_gap = -1.0
            yaw -= event.relative.x * DRAG_SENSITIVITY
            pitch = clampf(
                pitch + event.relative.y * DRAG_SENSITIVITY,
                deg_to_rad(3.0),
                deg_to_rad(70.0)
            )
            _update_camera()
        return

    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            dragging_mouse = event.pressed
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            distance = clampf(distance - 3.0, MIN_DISTANCE, MAX_DISTANCE)
            _update_camera()
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            distance = clampf(distance + 3.0, MIN_DISTANCE, MAX_DISTANCE)
            _update_camera()

    if event is InputEventMouseMotion and dragging_mouse:
        yaw -= event.relative.x * DRAG_SENSITIVITY
        pitch = clampf(
            pitch + event.relative.y * DRAG_SENSITIVITY,
            deg_to_rad(3.0),
            deg_to_rad(70.0)
        )
        _update_camera()

func _update_camera() -> void:
    if camera == null:
        return

    var horizontal := cos(pitch) * distance
    camera.position = target + Vector3(
        sin(yaw) * horizontal,
        sin(pitch) * distance,
        cos(yaw) * horizontal
    )
    camera.look_at(target, Vector3.UP)
