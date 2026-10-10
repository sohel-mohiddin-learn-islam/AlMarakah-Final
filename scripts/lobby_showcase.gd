extends Node3D

const MALE_CHARACTER = preload("res://assets/characters/quaternius/male/Superhero_Male_FullBody.gltf")
const FEMALE_CHARACTER = preload("res://assets/characters/quaternius/male/Superhero_Female_FullBody.gltf")
var settings: RefCounted
var lobby_camera: Camera3D
var lobby_character: Node3D
var _lobby_dragging := false
const LOBBY_ROTATION_SENSITIVITY := 0.45

func configure(prefs: RefCounted) -> void:
	settings = prefs

func _ready() -> void:
	_build_environment()
	_build_platform()
	_build_fortress()
	_build_character()
	_build_camera()

func _material(color: Color, metallic: float = 0.0, roughness: float = 0.8) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat

func _box(parent: Node3D, name: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.position = pos
	item.material_override = mat
	parent.add_child(item)
	return item

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.48, 0.48, 0.56)
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.48, 0.38, 0.29)
	env.fog_density = 0.008
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "GoldenHourSun"
	sun.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.78, 0.53)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)

	var fill := OmniLight3D.new()
	fill.position = Vector3(0.0, 4.0, 4.0)
	fill.light_color = Color(0.30, 0.55, 1.0)
	fill.light_energy = 1.1
	fill.omni_range = 12.0
	add_child(fill)

func _build_platform() -> void:
	var stone := _material(Color(0.20, 0.19, 0.18))
	var gold := _material(Color(0.76, 0.48, 0.16), 0.65, 0.28)
	_box(self, "MainStoneFloor", Vector3(34.0, 0.7, 34.0), Vector3(0.0, -0.45, 0.0), stone)
	_box(self, "CharacterDais", Vector3(4.8, 0.35, 4.8), Vector3(0.0, 0.05, 0.0), gold)
	_box(self, "DaisTop", Vector3(4.2, 0.15, 4.2), Vector3(0.0, 0.28, 0.0), stone)

func _build_fortress() -> void:
	var sandstone := _material(Color(0.43, 0.31, 0.22))
	var dark_stone := _material(Color(0.22, 0.19, 0.17))
	var gold := _material(Color(0.76, 0.48, 0.16), 0.55, 0.35)
	for side in [-1.0, 1.0]:
		_box(self, "FortressWall", Vector3(2.4, 7.5, 1.8), Vector3(side * 10.0, 3.2, -7.0), sandstone)
		_box(self, "WallCrown", Vector3(3.0, 0.6, 2.3), Vector3(side * 10.0, 7.25, -7.0), gold)
		_box(self, "Tower", Vector3(4.0, 10.0, 4.0), Vector3(side * 13.0, 4.2, -13.0), dark_stone)
		_box(self, "TowerCap", Vector3(4.6, 0.7, 4.6), Vector3(side * 13.0, 9.5, -13.0), gold)
		_box(self, "BannerPole", Vector3(0.12, 4.0, 0.12), Vector3(side * 13.0, 12.0, -13.0), gold)
		_box(self, "Banner", Vector3(1.5, 2.2, 0.12), Vector3(side * 13.0, 10.6, -13.0), sandstone)
	_box(self, "RearGate", Vector3(7.0, 6.0, 1.0), Vector3(0.0, 2.5, -11.0), sandstone)
	_box(self, "GateOpening", Vector3(3.2, 4.4, 0.25), Vector3(0.0, 1.7, -10.4), dark_stone)
	_box(self, "GateLintel", Vector3(4.0, 0.35, 0.5), Vector3(0.0, 4.2, -10.0), gold)

func _build_character() -> void:
	set_character(String(settings.data.get("character_id", "azlan")) if settings != null else "azlan")

func set_character(character_id: String) -> void:
	var chosen_id := "ayla" if character_id == "ayla" else "azlan"
	var old_rotation := 0.0
	if is_instance_valid(lobby_character):
		old_rotation = lobby_character.rotation.y
		lobby_character.queue_free()

	var character_scene: PackedScene = FEMALE_CHARACTER if chosen_id == "ayla" else MALE_CHARACTER
	var character := character_scene.instantiate() as Node3D
	character.name = "LobbyCharacter"
	lobby_character = character
	character.position = Vector3(0.0, 0.38, 0.0)
	character.scale = Vector3(1.25, 1.25, 1.25)
	character.rotation.y = old_rotation
	add_child(character)

	var animator_script = preload("res://scripts/character_animator.gd")
	var animator = animator_script.new()
	character.add_child(animator)
	animator.setup(character)

func _build_camera() -> void:
	lobby_camera = Camera3D.new()
	lobby_camera.name = "LobbyCamera"
	lobby_camera.position = Vector3(3.8, 2.65, 7.2)
	lobby_camera.fov = 36.0
	add_child(lobby_camera)
	lobby_camera.look_at(Vector3(0.0, 1.6, 0.0), Vector3.UP)
	lobby_camera.make_current()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_lobby_dragging = event.pressed

	elif event is InputEventScreenDrag:
		if _lobby_dragging and is_instance_valid(lobby_character):
			lobby_character.rotate_y(deg_to_rad(-event.relative.x * LOBBY_ROTATION_SENSITIVITY))

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_lobby_dragging = event.pressed

	elif event is InputEventMouseMotion:
		if _lobby_dragging and is_instance_valid(lobby_character):
			lobby_character.rotate_y(deg_to_rad(-event.relative.x * LOBBY_ROTATION_SENSITIVITY))
