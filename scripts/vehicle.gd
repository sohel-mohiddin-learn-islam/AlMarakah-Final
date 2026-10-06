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

    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(1.8, 1.0, 3.6)
    mesh.mesh = box
    mesh.position.y = 0.6
    add_child(mesh)

func enter_vehicle(actor: CharacterBody3D) -> bool:
    if occupied or not is_instance_valid(actor):
        return false

    driver = actor
    occupied = true
    return true

func exit_vehicle() -> CharacterBody3D:
    if not occupied or not is_instance_valid(driver):
        driver = null
        occupied = false
        return null

    var actor := driver
    driver = null
    occupied = false
    return actor

func _physics_process(delta: float) -> void:
    if not occupied:
        speed = move_toward(speed, 0.0, friction * delta)
        return

    speed = move_toward(speed, throttle * max_speed, acceleration * delta)

    if brake > 0.01:
        speed = move_toward(speed, 0.0, braking * brake * delta)

    steering = move_toward(steering, 0.0, 4.0 * delta)

    if absf(speed) > 0.2:
        rotation.y -= steering * steering_speed * delta * signf(speed)

    velocity = -global_transform.basis.z * speed
    move_and_slide()
