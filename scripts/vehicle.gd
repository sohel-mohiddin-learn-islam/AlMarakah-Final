extends CharacterBody3D
## Local vehicle controller. Networking and authoritative vehicle state are future work.

var max_speed: float = 24.0
var acceleration: float = 18.0
var braking: float = 28.0
var steering_speed: float = 2.4
var friction: float = 8.0

var speed: float = 0.0
var steering: float = 0.0
var throttle: float = 0.0
var brake: float = 0.0

var driver: CharacterBody3D = null
var driver_parent: Node = null
var occupied: bool = false

var wheel_front_left: Node3D = null
var wheel_front_right: Node3D = null
var wheel_back_left: Node3D = null
var wheel_back_right: Node3D = null
var vehicle_camera: Camera3D = null

func setup(spawn: Vector3) -> void:
    global_position = spawn
    collision_layer = 4
    collision_mask = 1

    var body_shape := BoxShape3D.new()
    body_shape.size = Vector3(1.8, 1.2, 3.6)

    var collider := CollisionShape3D.new()
    collider.shape = body_shape
    collider.position.y = 0.6
    add_child(collider)

    var vehicle_scene = preload("res://assets/vehicles/suv/AlMarakahSUV.glb")
    var vehicle_visual = vehicle_scene.instantiate()
    vehicle_visual.name = "RealisticSUV"
    vehicle_visual.position = Vector3(0.0, 0.0, 0.0)
    vehicle_visual.scale = Vector3.ONE
    add_child(vehicle_visual)

    wheel_front_left = vehicle_visual.get_node_or_null("wheel-front-left")
    wheel_front_right = vehicle_visual.get_node_or_null("wheel-front-right")
    wheel_back_left = vehicle_visual.get_node_or_null("wheel-back-left")
    wheel_back_right = vehicle_visual.get_node_or_null("wheel-back-right")

    vehicle_camera = Camera3D.new()
    vehicle_camera.name = "VehicleCamera"
    vehicle_camera.position = Vector3(0.0, 2.4, 6.5)
    vehicle_camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
    vehicle_camera.fov = 78.0
    vehicle_camera.far = 380.0
    add_child(vehicle_camera)

func enter_vehicle(actor: CharacterBody3D) -> bool:
    if occupied or not is_instance_valid(actor):
        return false

    driver = actor
    occupied = true

    driver_parent = actor.get_parent()
    actor.reparent(self)
    actor.position = Vector3(0.0, 1.25, 0.25)
    actor.rotation = Vector3.ZERO

    if actor.has_method("set_vehicle_visual_visible"):
        actor.set_vehicle_visual_visible(false)

    if is_instance_valid(vehicle_camera):
        vehicle_camera.make_current()

    return true

func exit_vehicle() -> CharacterBody3D:
    if not occupied or not is_instance_valid(driver):
        driver = null
        driver_parent = null
        occupied = false
        return null

    var actor := driver
    var exit_position := global_position + global_transform.basis.x * 2.4
    var parent := driver_parent

    if is_instance_valid(parent):
        actor.reparent(parent)
    else:
        actor.reparent(get_parent())

    actor.global_position = exit_position
    actor.rotation.y = rotation.y

    if actor.has_method("set_vehicle_visual_visible"):
        actor.set_vehicle_visual_visible(true)

    if actor.has_method("restore_player_camera"):
        actor.restore_player_camera()

    driver = null
    driver_parent = null
    occupied = false
    return actor

func _physics_process(delta: float) -> void:
    if not occupied:
        speed = move_toward(speed, 0.0, friction * delta)
        return

    throttle = Input.get_axis("vehicle_reverse", "vehicle_accelerate")
    steering = Input.get_axis("vehicle_right", "vehicle_left")
    brake = 1.0 if Input.is_action_pressed("vehicle_brake") else 0.0

    var driver_hud = driver.get("hud") if is_instance_valid(driver) else null
    if driver_hud != null:
        var mobile_move: Vector2 = driver_hud.move_vector
        if mobile_move.length() > 0.05:
            throttle = -mobile_move.y
            steering = -mobile_move.x

    speed = move_toward(speed, throttle * max_speed, acceleration * delta)

    if brake > 0.01:
        speed = move_toward(speed, 0.0, braking * brake * delta)

    steering = move_toward(steering, 0.0, 4.0 * delta)

    if absf(speed) > 0.2:
        rotation.y -= steering * steering_speed * delta * signf(speed)

    _update_wheels(delta)

    velocity = -global_transform.basis.z * speed
    move_and_slide()

func _update_wheels(delta: float) -> void:
    var steering_angle: float = steering * 0.45

    if is_instance_valid(wheel_front_left):
        wheel_front_left.rotation.y = steering_angle
        wheel_front_left.rotation.x -= speed * delta * 0.9

    if is_instance_valid(wheel_front_right):
        wheel_front_right.rotation.y = steering_angle
        wheel_front_right.rotation.x -= speed * delta * 0.9

    if is_instance_valid(wheel_back_left):
        wheel_back_left.rotation.x -= speed * delta * 0.9

    if is_instance_valid(wheel_back_right):
        wheel_back_right.rotation.x -= speed * delta * 0.9
