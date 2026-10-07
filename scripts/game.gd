extends Node3D
## Offline coordinator. Real matchmaking and authoritative servers are future work.
const Rules = preload("res://scripts/rules.gd")
const Settings = preload("res://scripts/settings.gd")
const Arena = preload("res://scripts/arena.gd")
const Bot = preload("res://scripts/bot.gd")
const Player = preload("res://scripts/player.gd")
const Vehicle = preload("res://scripts/vehicle.gd")
const HUD = preload("res://scripts/hud.gd")

var settings: RefCounted
var hud: CanvasLayer
var arena: Node3D
var world: Node3D
var actors: Array[Node3D] = []
var player: CharacterBody3D
var match_active: bool = false
var is_cs: bool = false
var mode: String = "br"
var mode_id: String = "br_classic"
var ranked: bool = false
var map_id: int = 0
var zone_radius: float = 125.0
var elapsed: float = 0.0
var damage_clock: float = 0.0
var hud_clock: float = 0.0
var kills: int = 0
var score: Array[int] = [0, 0]
var round_number: int = 1
var intermission: float = 0.0
var zone_visual: MeshInstance3D
var spectator: Camera3D
var pickups: Array[Node3D] = []
var vehicles: Array[Node3D] = []
var tracer_count: int = 0
var networked_match: bool = false
var network_role: String = "offline"
var local_peer_id: int = 1
var network_spawn_points: Array[Vector3] = []
var network_players: Dictionary = {}
var network_spawn_indices: Dictionary = {}

func _ready() -> void:
	_setup_network_state()
	if NetworkManager != null:
		NetworkManager.peer_joined.connect(_on_network_peer_joined)
		NetworkManager.peer_left.connect(_on_network_peer_left)
	_setup_inputs()
	settings = Settings.new()
	settings.load_settings()
	hud = HUD.new()
	add_child(hud)
	hud.configure(settings)
	hud.start_match.connect(start_match)
	hud.back_to_menu.connect(return_to_menu)
	return_to_menu()

func _on_network_peer_joined(peer_id: int) -> void:
	if not networked_match or not NetworkManager.is_host:
		return
	_spawn_network_player(peer_id)
	_sync_existing_network_players(peer_id)

func _on_network_peer_left(peer_id: int) -> void:
	if not networked_match:
		return
	if not NetworkManager.is_host:
		return
	if not network_players.has(peer_id):
		return
	var remote_player: Node = network_players[peer_id]
	network_players.erase(peer_id)
	network_spawn_indices.erase(peer_id)
	actors.erase(remote_player)
	if is_instance_valid(remote_player):
		remote_player.queue_free()
	network_remove_player.rpc(peer_id)

@rpc("authority", "reliable", "call_local")
func network_remove_player(peer_id: int) -> void:
	if not networked_match:
		return
	if peer_id == multiplayer.get_unique_id():
		return
	if not network_players.has(peer_id):
		return
	var player_to_remove: Node = network_players[peer_id]
	network_players.erase(peer_id)
	actors.erase(player_to_remove)
	if is_instance_valid(player_to_remove):
		player_to_remove.queue_free()

@rpc("authority", "reliable", "call_local")
func network_spawn_player(peer_id: int, spawn: Vector3) -> void:
	if not networked_match:
		return
	if peer_id == multiplayer.get_unique_id():
		return
	if network_players.has(peer_id):
		return
	var remote_player := Player.new()
	world.add_child(remote_player)
	remote_player.setup(self, spawn, -1, peer_id)
	actors.append(remote_player)
	network_players[peer_id] = remote_player

func _sync_existing_network_players(peer_id: int) -> void:
	if not networked_match or not NetworkManager.is_host:
		return
	if is_instance_valid(player):
		network_spawn_player.rpc_id(peer_id, multiplayer.get_unique_id(), player.global_position)
	for existing_peer_id in network_players:
		if int(existing_peer_id) == peer_id:
			continue
		var existing_player: Node = network_players[existing_peer_id]
		if not is_instance_valid(existing_player):
			continue
		network_spawn_player.rpc_id(peer_id, int(existing_peer_id), existing_player.global_position)

func _spawn_network_player(peer_id: int) -> void:
	if not networked_match or not NetworkManager.is_host:
		return
	if network_players.has(peer_id):
		return
	if not match_active or network_spawn_points.is_empty():
		return
	var spawn_index: int = -1
	for candidate in range(1, network_spawn_points.size()):
		if not network_spawn_indices.values().has(candidate):
			spawn_index = candidate
			break
	if spawn_index < 0:
		return
	network_spawn_indices[peer_id] = spawn_index
	var remote_player := Player.new()
	world.add_child(remote_player)
	remote_player.setup(self, network_spawn_points[spawn_index], -1, peer_id)
	actors.append(remote_player)
	network_players[peer_id] = remote_player
	network_spawn_player.rpc(peer_id, network_spawn_points[spawn_index])

func _setup_network_state() -> void:
	if multiplayer.multiplayer_peer == null:
		networked_match = false
		network_role = "offline"
		local_peer_id = 1
		return
	networked_match = true
	network_role = "host" if NetworkManager.is_host else "client"
	local_peer_id = multiplayer.get_unique_id()

func _setup_inputs() -> void:
	var keys = {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "jump": KEY_SPACE, "reload": KEY_R, "vehicle_accelerate": KEY_W, "vehicle_reverse": KEY_S, "vehicle_left": KEY_A, "vehicle_right": KEY_D, "vehicle_brake": KEY_SPACE, "vehicle_interact": KEY_V}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event = InputEventKey.new()
			event.physical_keycode = keys[action]
			InputMap.action_add_event(action, event)

@rpc("any_peer", "reliable")
func request_start_match(selected_mode: String, selected_map: int) -> void:
	if not networked_match or not NetworkManager.is_host:
		return
	if multiplayer.get_remote_sender_id() == 0:
		return
	network_start_match.rpc(selected_mode, selected_map)

@rpc("authority", "reliable", "call_local")
func network_start_match(selected_mode: String, selected_map: int) -> void:
	if not networked_match:
		return
	_start_match_local(selected_mode, selected_map)

func _start_match_local(selected_mode: String, selected_map: int) -> void:
	# Keep the short IDs as a small compatibility convenience for tests/tools.
	if selected_mode == "br" or selected_mode == "cs":
		selected_mode += "_classic"
	if selected_mode not in Rules.MODE_IDS:
		return
	mode_id = selected_mode
	mode = Rules.base_mode(mode_id)
	is_cs = mode == "cs"
	ranked = Rules.is_ranked(mode_id)
	map_id = clampi(selected_map, 0, 1)
	kills = 0
	score = [0, 0]
	round_number = 1
	_begin_round()

func start_match(selected_mode: String, selected_map: int) -> void:
	if networked_match:
		if NetworkManager.is_host:
			network_start_match.rpc(selected_mode, selected_map)
		else:
			if multiplayer.get_peers().is_empty():
				_start_match_local(selected_mode, selected_map)
			else:
				request_start_match.rpc_id(1, selected_mode, selected_map)
		return
	_start_match_local(selected_mode, selected_map)

func _clear_world() -> void:
	match_active = false
	intermission = 0
	actors.clear()
	network_players.clear()
	network_spawn_indices.clear()
	pickups.clear()
	vehicles.clear()
	player = null
	spectator = null
	zone_visual = null
	tracer_count = 0
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = Node3D.new()
	add_child(world)

func _begin_round() -> void:
	_clear_world()
	arena = Arena.new()
	world.add_child(arena)
	arena.build(map_id, is_cs)
	_spawn_vehicles()
	zone_radius = arena.extent
	elapsed = 0
	damage_clock = 0
	var count: int = Rules.participant_count(mode_id)
	var spawns: Array[Vector3] = arena.spawn_points(count, is_cs)
	if networked_match:
		network_spawn_points = spawns.duplicate()
	player = Player.new()
	world.add_child(player)
	player.setup(self, spawns[0], 0 if is_cs else -1)
	actors.append(player)
	for i in range(1, count):
		var bot = Bot.new()
		world.add_child(bot)
		var side: int = (0 if i < Rules.CS_TEAM_SIZE else 1) if is_cs else i
		bot.setup(self, spawns[i], side)
		actors.append(bot)
	if not is_cs:
		_create_zone()
	match_active = true
	hud.show_match()
	if not OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_hud()

func _spawn_vehicles() -> void:
	var vehicle := Vehicle.new()
	world.add_child(vehicle)

	var spawn_position := Vector3(8.0, 1.0, 8.0)
	if is_instance_valid(arena):
		var points: Array[Vector3] = arena.spawn_points(2, is_cs)
		if points.size() >= 2:
			spawn_position = points[1]

	vehicle.setup(spawn_position)
	vehicles.append(vehicle)
func return_to_menu() -> void:
	_clear_world()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	arena = Arena.new()
	world.add_child(arena)
	arena.build(0, true)
	var view = Camera3D.new()
	world.add_child(view)
	view.position = Vector3(35, 30, 38)
	view.look_at(Vector3.ZERO)
	view.make_current()
	hud.show_lobby()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	if intermission > 0:
		intermission -= delta
		if intermission <= 0:
			_begin_round()
		return
	if not match_active:
		return
	elapsed += delta
	if is_cs:
		if elapsed >= Rules.CS_ROUND_SECONDS:
			_check_resolution()
	else:
		zone_radius = Rules.radius_at(elapsed, arena.extent)
		if is_instance_valid(zone_visual):
			zone_visual.scale = Vector3(zone_radius, 1, zone_radius)
		damage_clock += delta
		if damage_clock >= 1.0:
			damage_clock -= 1.0
			for actor in actors:
				if actor.alive and Vector2(actor.position.x, actor.position.z).length() > zone_radius:
					actor.take_damage(Rules.zone_damage_at(elapsed), null)
			_check_resolution()
	if is_instance_valid(player) and player.alive:
		for item in pickups.duplicate():
			if item.position.distance_squared_to(player.position) < 5.0:
				player.reserve = mini(player.reserve + 30, player.reserve_capacity)
				player.health = minf(player.health + 20, player.MAX_HEALTH)
				pickups.erase(item)
				item.queue_free()

func _process(delta: float) -> void:
	hud_clock += delta
	if is_instance_valid(player) and hud_clock > 0.1:
		hud_clock = 0
		_update_hud()
	if is_instance_valid(spectator) and (match_active or intermission > 0):
		var target: Node3D = null
		for actor in actors:
			if actor.alive and (not is_cs or actor.team == 0):
				target = actor
				break
		if target == null:
			for actor in actors:
				if actor.alive:
					target = actor
					break
		if target:
			var point: Vector3 = target.global_position
			spectator.global_position = spectator.global_position.lerp(point + Vector3(0, 12, 14), minf(delta * 3, 1))
			spectator.look_at(point + Vector3.UP)

func are_enemies(a: Node, b: Node) -> bool:
	return a != b and Rules.enemies(is_cs, a.team, b.team)

func fire_ray(origin: Vector3, direction: Vector3, attacker: Node, damage: float, distance: float) -> void:
	if not match_active or not is_instance_valid(attacker) or not attacker.alive:
		return
	var end: Vector3 = origin + direction.normalized() * distance
	var query = PhysicsRayQueryParameters3D.create(origin, end, 3, [attacker.get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		end = hit.position
		var victim = hit.collider
		if victim.has_method("take_damage") and are_enemies(attacker, victim):
			victim.take_damage(damage, attacker)
	# Only draw nearby traces. AI can fire far away without spawning effects.
	if is_instance_valid(player) and (attacker == player or origin.distance_squared_to(player.position) < 2500):
		_draw_tracer(origin, end, attacker == player)

func assisted_direction(origin: Vector3, direction: Vector3, attacker: Node) -> Vector3:
	var best_dot: float = cos(deg_to_rad(3.5))
	var chosen: Vector3 = direction
	for actor in actors:
		if not actor.alive or not are_enemies(attacker, actor):
			continue
		var point: Vector3 = actor.global_position + Vector3(0, 1.1, 0)
		if origin.distance_squared_to(point) > 6400:
			continue
		var candidate: Vector3 = (point - origin).normalized()
		var alignment: float = direction.dot(candidate)
		if alignment > best_dot:
			var query = PhysicsRayQueryParameters3D.create(origin, point, 3, [attacker.get_rid()])
			var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
			if hit.get("collider") == actor:
				best_dot = alignment
				chosen = candidate
	return direction.lerp(chosen, 0.3).normalized()

func actor_eliminated(actor: Node, attacker: Node) -> void:
	if not match_active:
		return
	if attacker == player:
		kills += 1
	if actor == player:
		spectator = Camera3D.new()
		world.add_child(spectator)
		spectator.global_transform = player.camera.global_transform
		spectator.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not is_cs and pickups.size() < 30:
		_drop_supply(actor.position)
	# Resolve after all simultaneous zone damage, never inside a physics query.
	_check_resolution.call_deferred()

func _check_resolution() -> void:
	if not match_active:
		return
	if is_cs:
		var living: Array[int] = [0, 0]
		var health_sum: Array[float] = [0.0, 0.0]
		for actor in actors:
			if actor.alive:
				living[actor.team] += 1
				health_sum[actor.team] += actor.health
		var winner: int = Rules.cs_winner(living, health_sum, elapsed >= Rules.CS_ROUND_SECONDS)
		if winner == -2:
			return
		match_active = false
		if winner >= 0:
			score[winner] += 1
		if score[0] >= Rules.CS_ROUNDS_TO_WIN or score[1] >= Rules.CS_ROUNDS_TO_WIN:
			_finish_match("TEAM VICTORY" if score[0] > score[1] else "TEAM DEFEAT")
		else:
			round_number += 1
			intermission = 3.0
	else:
		var survivors: Array[Node3D] = []
		for actor in actors:
			if actor.alive:
				survivors.append(actor)
		if survivors.size() <= 1:
			if survivors.size() == 1 and survivors[0] == player:
				_finish_match("LAST SURVIVOR — VICTORY")
			else:
				_finish_match("MATCH COMPLETE")

func _finish_match(title: String) -> void:
	match_active = false
	intermission = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var detail: String = "Team score %d : %d" % [score[0], score[1]] if is_cs else "%d eliminations" % kills
	var rating_text: String = "Offline bot practice • no competitive rating"
	if ranked:
		var won: bool = title.contains("VICTORY")
		var rating_key: String = "cs_rating" if is_cs else "br_rating"
		var delta: int = Rules.rating_delta(mode_id, won)
		var rating: int = clampi(int(settings.data.get(rating_key, 1000)) + delta, 0, 5000)
		settings.data[rating_key] = rating
		settings.save()
		rating_text = "Local %s rating %d (%+d) • offline practice" % ["CS" if is_cs else "BR", rating, delta]
	hud.show_result(title + "\n" + detail + "\n" + rating_text)

func _update_hud() -> void:
	var living: int = 0
	for actor in actors:
		if actor.alive:
			living += 1
	var zone_text: String
	if is_cs:
		zone_text = "Next round in %ds" % ceili(intermission) if intermission > 0 else "Round time %ds" % ceili(maxf(0, Rules.CS_ROUND_SECONDS - elapsed))
	elif elapsed < Rules.ZONE_WAIT:
		zone_text = "Zone shrinks in %ds" % ceili(Rules.ZONE_WAIT - elapsed)
	else:
		zone_text = "Safe radius %dm • Move toward the blue ring" % roundi(zone_radius)
	if not is_cs and player.alive and Vector2(player.position.x, player.position.z).length() > zone_radius:
		zone_text = "OUTSIDE SAFE ZONE — move toward the center!"
	hud.update_status({"health": player.health, "ammo": player.ammo, "reserve": player.reserve, "alive": living, "kills": kills, "zone": zone_text, "mode": Rules.mode_label(mode_id), "score": "%d : %d" % [score[0], score[1]], "round": round_number, "reloading": player.reload_time > 0, "reload_progress": 1.0 - player.reload_time / maxf(player.reload_seconds, 0.01), "weapon": player.weapon_id, "magazine_size": player.magazine_size, "eliminated": not player.alive})
	hud.update_radar(player.position, player.yaw, zone_radius, arena.extent, [], is_cs)

func _create_zone() -> void:
	zone_visual = MeshInstance3D.new()
	var mesh = ImmediateMesh.new()
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.8, 1, 0.28)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	for i in 96:
		var a: float = TAU * i / 96.0
		var b: float = TAU * (i + 1) / 96.0
		var p: Vector3 = Vector3(cos(a), 0.1, sin(a))
		var q: Vector3 = Vector3(cos(b), 0.1, sin(b))
		for vertex in [p, q, p + Vector3.UP * 5, q, q + Vector3.UP * 5, p + Vector3.UP * 5]:
			mesh.surface_add_vertex(vertex)
	mesh.surface_end()
	zone_visual.mesh = mesh
	world.add_child(zone_visual)
	zone_visual.scale = Vector3(zone_radius, 1, zone_radius)

func _draw_tracer(from: Vector3, to: Vector3, local_shot: bool) -> void:
	if tracer_count >= 24 or from.distance_squared_to(to) < 0.01:
		return
	tracer_count += 1
	var node = MeshInstance3D.new()
	var mesh = ImmediateMesh.new()
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("ffe7a2") if local_shot else Color("ef9e77")
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()
	node.mesh = mesh
	world.add_child(node)
	# Node-bound tween dies safely on world teardown.
	var tween = node.create_tween()
	tween.tween_interval(0.07)
	tween.tween_callback(func():
		tracer_count = maxi(0, tracer_count - 1)
		node.queue_free()
	)

func _drop_supply(at: Vector3) -> void:
	var item = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.6, 0.4, 0.6)
	item.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color("60d9b0")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	item.material_override = mat
	item.position = Vector3(at.x, 0.4, at.z)
	world.add_child(item)
	pickups.append(item)
