extends Node3D

const CONTROLS_SCRIPT = preload("res://scripts/palace_touch_controls.gd")
const ROYAL_FORTRESS_SCRIPT = preload("res://scripts/royal_fortress_palace.gd")
const CHARACTER_SCENE = preload("res://assets/characters/quaternius/male/Superhero_Male_FullBody.gltf")
const ANIMATOR_SCRIPT = preload("res://scripts/character_animator.gd")

const WALK_SPEED := 4.0
const JUMP_VELOCITY := 4.5
const LOOK_SENSITIVITY := 0.004
const PLAYER_LAYER := 2
const WORLD_LAYER := 1

var player: CharacterBody3D
var character_animator: Node
var camera_pivot: Node3D
var camera: Camera3D
var movement_input := Vector2.ZERO
var yaw := 0.0
var pitch := -0.12

var controls_layer: CanvasLayer
var controls: Variant
var status_label: Label

var look_finger := -1
var last_look_position := Vector2.ZERO
var generated_collision_count := 0
var last_reported_blocker := ""


func _ready() -> void:
    _create_world()
    _create_player()
    _create_ui()


func _create_world() -> void:
    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.72, 0.76, 0.82)
    env.ambient_light_energy = 0.8
    environment.environment = env
    add_child(environment)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
    sun.light_energy = 1.15
    sun.shadow_enabled = false
    add_child(sun)

    var palace: Node3D = ROYAL_FORTRESS_SCRIPT.new()
    palace.name = "CustomRoyalFortressPalace"
    palace.position = Vector3.ZERO
    add_child(palace)

    # Temporary outdoor floor gives the player a safe starting area.
    var floor_body := StaticBody3D.new()
    floor_body.name = "WalkTestGround"
    floor_body.collision_layer = WORLD_LAYER
    floor_body.collision_mask = 0
    floor_body.position = Vector3(0.0, -0.2, 0.0)
    add_child(floor_body)

    var floor_mesh := MeshInstance3D.new()
    var floor_box := BoxMesh.new()
    floor_box.size = Vector3(80.0, 0.4, 80.0)
    floor_mesh.mesh = floor_box
    var floor_material := StandardMaterial3D.new()
    floor_material.albedo_color = Color("#b6a080")
    floor_material.roughness = 0.95
    floor_mesh.material_override = floor_material
    floor_body.add_child(floor_mesh)

    var floor_shape := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = floor_box.size
    floor_shape.shape = box_shape
    floor_body.add_child(floor_shape)


func _add_mesh_collisions(node: Node) -> void:
    for child in node.get_children():
        if child is MeshInstance3D:
            var mesh_instance := child as MeshInstance3D
            if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
                # Collision generation is confined to this test scene.
                mesh_instance.create_trimesh_collision()
                generated_collision_count += 1
        _add_mesh_collisions(child)


func _create_player() -> void:
    player = CharacterBody3D.new()
    player.name = "WalkTestPlayer"
    player.position = Vector3(0.0, 1.0, 25.0)
    player.collision_layer = PLAYER_LAYER
    player.collision_mask = WORLD_LAYER
    add_child(player)

    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.32
    capsule.height = 1.75

    var collider := CollisionShape3D.new()
    collider.name = "PlayerCollision"
    collider.shape = capsule
    collider.position.y = 0.88
    player.add_child(collider)

    var body := Node3D.new()
    body.name = "CharacterVisual"
    player.add_child(body)

    var character := CHARACTER_SCENE.instantiate()
    character.name = "ExistingMaleCharacter"
    character.scale = Vector3.ONE
    body.add_child(character)

    character_animator = ANIMATOR_SCRIPT.new()
    character_animator.name = "PalaceTestCharacterAnimator"
    body.add_child(character_animator)
    character_animator.setup(character)

    if not character_animator.initialized:
        push_warning("Palace Walk Test: animator failed to initialize; check animation and bone names.")

    camera_pivot = Node3D.new()
    camera_pivot.name = "CameraPivot"
    camera_pivot.position.y = 1.55
    player.add_child(camera_pivot)

    var arm := SpringArm3D.new()
    arm.name = "ThirdPersonSpringArm"
    arm.spring_length = 3.5
    arm.margin = 0.2
    arm.collision_mask = WORLD_LAYER
    camera_pivot.add_child(arm)

    camera = Camera3D.new()
    camera.name = "WalkTestCamera"
    camera.fov = 75.0
    camera.far = 300.0
    arm.add_child(camera)
    camera.make_current()


func _create_ui() -> void:
    controls_layer = CanvasLayer.new()
    controls_layer.name = "WalkTestTouchUI"
    add_child(controls_layer)

    controls = CONTROLS_SCRIPT.new()
    controls.name = "VirtualJoystick"
    controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    controls_layer.add_child(controls)
    controls.movement_changed.connect(_on_movement_changed)
    controls.set_controls_enabled(true)

    var title := Label.new()
    title.position = Vector2(18.0, 14.0)
    title.size = Vector2(290.0, 32.0)
    title.text = "PALACE WALK TEST"
    title.add_theme_font_size_override("font_size", 20)
    controls_layer.add_child(title)

    status_label = Label.new()
    status_label.position = Vector2(18.0, 48.0)
    status_label.size = Vector2(320.0, 42.0)
    status_label.text = "Left joystick: move | Right side: look"
    status_label.add_theme_font_size_override("font_size", 13)
    controls_layer.add_child(status_label)


func _on_movement_changed(direction: Vector2) -> void:
    movement_input = direction.limit_length()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            if touch.position.x >= get_viewport().get_visible_rect().size.x * 0.48:
                if look_finger == -1:
                    look_finger = touch.index
                    last_look_position = touch.position
        elif touch.index == look_finger:
            look_finger = -1

    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == look_finger:
            _apply_look(drag.relative)

    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        _apply_look((event as InputEventMouseMotion).relative)

    elif event is InputEventKey and event.pressed and not event.echo:
        var key := event as InputEventKey
        if key.keycode == KEY_SPACE and player.is_on_floor():
            player.velocity.y = JUMP_VELOCITY


func _apply_look(relative: Vector2) -> void:
    yaw -= relative.x * LOOK_SENSITIVITY
    pitch = clampf(pitch - relative.y * LOOK_SENSITIVITY, -1.0, 0.65)
    player.rotation.y = yaw
    camera_pivot.rotation.x = pitch


func _physics_process(delta: float) -> void:
    if not is_instance_valid(player):
        return

    if not player.is_on_floor():
        player.velocity.y -= 18.0 * delta

    var input := movement_input
    if Input.is_key_pressed(KEY_W):
        input.y -= 1.0
    if Input.is_key_pressed(KEY_S):
        input.y += 1.0
    if Input.is_key_pressed(KEY_A):
        input.x -= 1.0
    if Input.is_key_pressed(KEY_D):
        input.x += 1.0
    input = input.limit_length()

    var forward := -player.global_basis.z
    var right := player.global_basis.x
    var direction := right * input.x + forward * -input.y

    if direction.length() > 1.0:
        direction = direction.normalized()

    player.velocity.x = direction.x * WALK_SPEED
    player.velocity.z = direction.z * WALK_SPEED
    player.move_and_slide()

    if character_animator != null and character_animator.initialized:
        var movement_amount: float = 0.25 if input.length_squared() > 0.01 else 0.0
        character_animator.update_state(
            movement_amount,
            player.is_on_floor(),
            false,
            false,
            delta,
            0.0,
            input
        )

    if direction.length_squared() > 0.01:
        for i in range(player.get_slide_collision_count()):
            var hit = player.get_slide_collision(i)
            if hit.get_normal().y < 0.5:
                var collider = hit.get_collider()
                if collider is Node:
                    var blocker_path := str(collider.get_path())
                    if blocker_path != last_reported_blocker:
                        last_reported_blocker = blocker_path
                        print("Palace Walk Test: horizontal blocker: ", blocker_path)
