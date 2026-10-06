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

    var vehicle_scene = preload("res://assets/vehicles/suv/BattleRoyaleSUV.glb")
    var vehicle_visual = vehicle_scene.instantiate()
    vehicle_visual.name = "RealisticSUV"
    vehicle_visual.position = Vector3(0.0, 0.0, 0.0)
    vehicle_visual.scale = Vector3.ONE
    add_child(vehicle_visual)

func enter_vehicle(actor: CharacterBody3D) -> bool:
    if occupied or not is_instance_valid(actor):
        return false

    driver = actor
    occupied = true

    driver_parent = actor.get_parent()
    actor.reparent(self)
    actor.position = Vector3(0.0, 1.25, 0.25)
    actor.rotation = Vector3.ZERO

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

    driver = null
    driver_parent = null
    occupied = false
    return actor

func _physics_process(delta: float) -> void:
    if not occupied:
        speed = move_toward(speed, 0.0, friction * delta)
        return

    throttle = Input.get_axis("vehicle_reverse", "vehicle_accelerate")
    brake = 1.0 if Input.is_action_pressed("vehicle_brake") else 0.0
    steering = Input.get_axis("vehicle_right", "vehicle_left")

    speed = move_toward(speed, throttle * max_speed, acceleration * delta)

    if brake > 0.01:
        speed = move_toward(speed, 0.0, braking * brake * delta)

    steering = move_toward(steering, 0.0, 4.0 * delta)

    if absf(speed) > 0.2:
        rotation.y -= steering * steering_speed * delta * signf(speed)

    velocity = -global_transform.basis.z * speed
    move_and_slide()
