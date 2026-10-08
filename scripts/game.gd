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
var spectator_target: Node3D = null
var pickups: Array[Node3D] = []
var vehicles: Array[Node3D] = []
var tracer_count: int = 0
var networked_match: bool = false
var network_role: String = "offline"
var local_peer_id: int = 1
var network_spawn_points: Array[Vector3] = []
var network_players: Dictionary = {}
var network_spawn_indices: Dictionary = {}
var network_local_spawn_index: int = 0
var network_ready_peer_ids: Array = []
var network_match_locked: bool = false
var network_match_session_id: int = 0
var network_room_session_id: int = 0
var network_bot_slots: Dictionary = {}
var network_bots: Dictionary = {}
var network_snapshot_timer: float = 0.0
var network_resolution_sent: bool = false
var network_round_pending: bool = false

func is_in_network_room() -> bool:
	return networked_match and network_room_session_id > 0

func _ready() -> void:
	_setup_network_state()
	if NetworkManager != null:
		NetworkManager.peer_joined.connect(_on_network_peer_joined)
		NetworkManager.peer_left.connect(_on_network_peer_left)
		NetworkManager.matchmaking_locked.connect(_on_matchmaking_locked)
	_setup_inputs()
	settings = Settings.new()
	settings.load_settings()
	hud = HUD.new()
	add_child(hud)
	hud.configure(settings)
	hud.start_match.connect(start_match)
	hud.back_to_menu.connect(return_to_menu)
	hud.spectator_previous.connect(_on_spectator_previous)
	hud.spectator_next.connect(_on_spectator_next)
	return_to_menu()

func _on_matchmaking_locked(selected_mode: String, selected_map: int, ready_peer_ids: Array, session_id: int) -> void:
	if not networked_match or not NetworkManager.is_host:
		return
	network_ready_peer_ids = ready_peer_ids.duplicate()
	network_match_locked = true
	network_match_session_id = session_id
	network_room_session_id = session_id
	print("MATCHMAKING LOCKED: mode=", selected_mode, " map=", selected_map, " humans=", network_ready_peer_ids)
	network_start_match.rpc(selected_mode, selected_map, network_ready_peer_ids, network_match_session_id)

func _on_network_peer_joined(peer_id: int) -> void:
	if not networked_match or not NetworkManager.is_host:
		return
	print("PLAYER CONNECTED TO LOBBY: peer=", peer_id)
	if not match_active:
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

@rpc("authority", "reliable", "call_remote")
func network_spawn_bot(bot_id: int, spawn: Vector3, team_id: int) -> void:
	if not networked_match:
		return
	if bot_id <= 0:
		return
	if network_bots.has(bot_id):
		return
	var replica := Bot.new()
	world.add_child(replica)
	replica.setup_network_replica(self, spawn, team_id, bot_id)
	network_bots[bot_id] = replica

@rpc("authority", "unreliable", "call_remote")
func network_play_remote_fire(peer_id: int, fire_pitch: float) -> void:
	if not networked_match:
		return
	if multiplayer.get_remote_sender_id() != 1:
		return
	if peer_id == multiplayer.get_unique_id():
		return
	if not network_players.has(peer_id):
		return
	var remote_player: Node = network_players[peer_id]
	if not is_instance_valid(remote_player):
		return
	remote_player.pitch = fire_pitch
	if remote_player.animator != null:
		remote_player.animator.play_shoot()

@rpc("authority", "unreliable", "call_remote")
func network_draw_tracer(origin: Vector3, end: Vector3) -> void:
	if not networked_match:
		return
	if multiplayer.get_remote_sender_id() != 1:
		return
	_draw_tracer(origin, end, false)

@rpc("authority", "reliable", "call_remote")
func network_eliminate_actor(actor_id: int, actor_is_bot: bool) -> void:
	if not networked_match:
		return
	if multiplayer.get_remote_sender_id() != 1:
		return
	if actor_is_bot:
		if not network_bots.has(actor_id):
			return
		var bot_replica: Node = network_bots[actor_id]
		if not is_instance_valid(bot_replica):
			return
		bot_replica.network_alive = false
		bot_replica.alive = false
		bot_replica.collision_layer = 0
		bot_replica.collision_mask = 0
		if bot_replica.has_method("set_network_eliminated"):
			bot_replica.set_network_eliminated()
		return
	if actor_id == multiplayer.get_unique_id():
		if is_instance_valid(player):
			_start_spectator_camera()
		return
	if not network_players.has(actor_id):
		return
	var player_replica: Node = network_players[actor_id]
	if not is_instance_valid(player_replica):
		return
	player_replica.network_alive = false
	player_replica.alive = false
	player_replica.set_deferred("collision_layer", 0)
	if is_instance_valid(player_replica.body):
		player_replica.body.visible = false

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
	for bot_id in network_bot_slots:
		var existing_bot: Node = network_bot_slots[bot_id]
		if not is_instance_valid(existing_bot):
			continue
		var bot_team: int = int(existing_bot.team)
		network_spawn_bot.rpc_id(peer_id, int(bot_id), existing_bot.global_position, bot_team)

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

func _spawn_locked_human_players() -> void:
	if not networked_match or not NetworkManager.is_host:
		return
	if network_spawn_points.is_empty():
		return
	network_players.clear()
	network_spawn_indices.clear()
	for index in range(network_ready_peer_ids.size()):
		var peer_id: int = int(network_ready_peer_ids[index])
		if index >= network_spawn_points.size():
			break
		var spawn_position: Vector3 = network_spawn_points[index]
		network_spawn_indices[peer_id] = index
		if peer_id == multiplayer.get_unique_id():
			continue
		var remote_player := Player.new()
		world.add_child(remote_player)
		remote_player.setup(self, spawn_position, -1, peer_id)
		actors.append(remote_player)
		network_players[peer_id] = remote_player
		network_spawn_player.rpc(peer_id, spawn_position)

func _setup_network_state() -> void:
	if not NetworkManager.connected:
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
	network_start_match.rpc(selected_mode, selected_map, network_ready_peer_ids, network_match_session_id)

@rpc("authority", "reliable", "call_local")
func network_start_match(selected_mode: String, selected_map: int, locked_peer_ids: Array, session_id: int) -> void:
	if not networked_match:
		return
	if session_id <= 0:
		return
	network_match_session_id = session_id
	network_room_session_id = session_id
	network_ready_peer_ids = locked_peer_ids.duplicate()
	var my_peer_id: int = multiplayer.get_unique_id()
	var local_index: int = network_ready_peer_ids.find(my_peer_id)
	if local_index < 0:
		return
	network_local_spawn_index = local_index
	network_match_locked = true
	if NetworkManager.is_host and network_room_session_id > 0:
		NetworkManager.start_match_room(network_room_session_id)
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
			NetworkManager.request_matchmaking_ready(selected_mode, selected_map)
		else:
			NetworkManager.request_matchmaking_ready.rpc_id(1, selected_mode, selected_map)
		return
	_start_match_local(selected_mode, selected_map)

func _clear_world() -> void:
	network_resolution_sent = false
	network_round_pending = false
	match_active = false
	intermission = 0
	actors.clear()
	network_players.clear()
	network_spawn_indices.clear()
	network_local_spawn_index = 0
	network_bot_slots.clear()
	if not network_bots.is_empty():
		for bot_id in network_bots:
			var replica: Node = network_bots[bot_id]
			if is_instance_valid(replica):
				replica.queue_free()
	network_bots.clear()
	pickups.clear()
	vehicles.clear()
	player = null
	spectator = null
	spectator_target = null
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
	var local_spawn_index: int = 0
	if networked_match and network_match_locked:
		local_spawn_index = network_local_spawn_index
	player.setup(self, spawns[local_spawn_index], 0 if is_cs else -1)
	actors.append(player)
	if networked_match and NetworkManager.is_host and network_match_locked:
		_spawn_locked_human_players()
		var human_count: int = network_ready_peer_ids.size()
		for i in range(human_count, count):
			var bot = Bot.new()
			world.add_child(bot)
			var side: int = (0 if i < Rules.CS_TEAM_SIZE else 1) if is_cs else i
			bot.setup(self, spawns[i], side)
			actors.append(bot)
			var bot_id: int = 1000 + i
			network_bot_slots[bot_id] = bot
			network_spawn_bot.rpc(bot_id, spawns[i], side)
	elif not networked_match:
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

	if networked_match and NetworkManager.is_host:
		network_snapshot_timer -= delta
		if network_snapshot_timer <= 0.0:
			network_snapshot_timer = 0.05
			_send_network_snapshot_batch()

func _send_network_snapshot_batch() -> void:
	if not networked_match or not NetworkManager.is_host:
		return
	var snapshots: Array = []
	for peer_id in network_players:
		var remote_player: Node = network_players[peer_id]
		if not is_instance_valid(remote_player):
			continue
		snapshots.append([int(peer_id), remote_player.global_position, remote_player.velocity, remote_player.yaw, remote_player.pitch, remote_player.alive, remote_player.network_movement_amount, remote_player.network_aiming, remote_player.network_sprinting, remote_player.network_grounded])
	if is_instance_valid(player):
		snapshots.append([multiplayer.get_unique_id(), player.global_position, player.velocity, player.yaw, player.pitch, player.alive, player.network_movement_amount, player.network_aiming, player.network_sprinting, player.network_grounded])
	for bot_id in network_bot_slots:
		var bot: Node = network_bot_slots[bot_id]
		if not is_instance_valid(bot):
			continue
		snapshots.append([int(bot_id), bot.global_position, bot.velocity, bot.network_yaw, bot.alive])
	for peer_id in multiplayer.get_peers():
		receive_network_snapshot_batch.rpc_id(peer_id, snapshots)

@rpc("authority", "unreliable", "call_remote")
func receive_network_snapshot_batch(snapshots: Array) -> void:
	if not networked_match:
		return
	if multiplayer.get_remote_sender_id() != 1:
		return
	for snapshot in snapshots:
		if not snapshot is Array:
			continue
		if snapshot.size() == 5:
			var bot_id: int = int(snapshot[0])
			if not network_bots.has(bot_id):
				continue
			var replica: Node = network_bots[bot_id]
			if not is_instance_valid(replica):
				continue
			replica.network_position = snapshot[1]
			replica.network_velocity = snapshot[2]
			replica.network_yaw = float(snapshot[3])
			replica.network_alive = bool(snapshot[4])
			continue
		if snapshot.size() < 10:
			continue
		var peer_id: int = int(snapshot[0])
		if peer_id == multiplayer.get_unique_id():
			continue
		if not network_players.has(peer_id):
			continue
		var remote_player: Node = network_players[peer_id]
		if not is_instance_valid(remote_player):
			continue
		remote_player.network_position = snapshot[1]
		remote_player.network_velocity = snapshot[2]
		remote_player.network_snapshot_age = 0.0
		remote_player.network_yaw = float(snapshot[3])
		remote_player.network_pitch = float(snapshot[4])
		remote_player.network_alive = bool(snapshot[5])
		remote_player.network_movement_amount = float(snapshot[6])
		remote_player.network_aiming = bool(snapshot[7])
		remote_player.network_sprinting = bool(snapshot[8])
		remote_player.network_grounded = bool(snapshot[9])
func _on_spectator_previous() -> void:
	spectator_previous()

func _on_spectator_next() -> void:
	spectator_next()

@rpc("authority", "reliable", "call_remote")
func network_begin_round() -> void:
	if not networked_match:
		return
	if multiplayer.get_remote_sender_id() != 1:
		return
	network_round_pending = false
	_begin_round()

func _process(delta: float) -> void:
	hud_clock += delta

	if is_instance_valid(player) and hud_clock > 0.1:
		hud_clock = 0
		_update_hud()

	# CS round intermission is controlled by the host.
	if is_cs and networked_match and network_round_pending and intermission > 0:
		intermission = maxf(intermission - delta, 0.0)

		if NetworkManager.is_host and intermission <= 0.0:
			network_round_pending = false
			network_begin_round.rpc()
			_begin_round()

	if is_instance_valid(spectator) and (match_active or intermission > 0):
		if not _is_valid_spectator_target():
			_set_spectator_target(_find_spectator_target(1))
		if is_instance_valid(spectator_target):
			var point: Vector3 = spectator_target.global_position
			spectator.global_position = spectator.global_position.lerp(
				point + Vector3(0, 12, 14),
				minf(delta * 3, 1)
			)
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
		if attacker == player:
			print("PLAYER SHOT HIT: ", victim.name, " type=", victim.get_class(), " has_damage=", victim.has_method("take_damage"))
		if victim.has_method("take_damage") and are_enemies(attacker, victim):
			victim.take_damage(damage, attacker)
	# Only draw nearby traces. AI can fire far away without spawning effects.
	if is_instance_valid(player) and (attacker == player or origin.distance_squared_to(player.position) < 2500):
		_draw_tracer(origin, end, attacker == player)
	if networked_match and NetworkManager.is_host and attacker != player:
		for peer_id in multiplayer.get_peers():
			network_draw_tracer.rpc_id(peer_id, origin, end)

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
	if networked_match and NetworkManager.is_host:
		if actor is Bot:
			if actor.network_id > 0:
				for peer_id in multiplayer.get_peers():
					network_eliminate_actor.rpc_id(peer_id, actor.network_id, true)
		elif actor is Player:
			if actor.network_peer_id > 0:
				for peer_id in multiplayer.get_peers():
					network_eliminate_actor.rpc_id(peer_id, actor.network_peer_id, false)
	if attacker == player:
		kills += 1
	if actor == player:
		_start_spectator_camera()
	elif not is_cs and pickups.size() < 30:
		_drop_supply(actor.position)
	# Resolve after all simultaneous zone damage, never inside a physics query.
	_check_resolution.call_deferred()

func _is_valid_spectator_target() -> bool:
	return is_instance_valid(spectator_target) and spectator_target.alive and spectator_target in actors

func _find_spectator_target(direction: int) -> Node3D:
	var candidates: Array[Node3D] = []
	for actor in actors:
		if not is_instance_valid(actor) or not actor.alive:
			continue
		if actor == player:
			continue
		if is_cs and actor.team != 0:
			continue
		candidates.append(actor)

	if candidates.is_empty() and is_cs:
		for actor in actors:
			if not is_instance_valid(actor) or not actor.alive or actor == player:
				continue
			candidates.append(actor)

	if candidates.is_empty():
		return null

	var current_index: int = candidates.find(spectator_target)
	if current_index < 0:
		current_index = 0 if direction >= 0 else candidates.size() - 1
	else:
		current_index = posmod(current_index + direction, candidates.size())

	return candidates[current_index]

func _set_spectator_target(target: Node3D) -> void:
	spectator_target = target
	if not is_instance_valid(hud):
		return
	if not is_instance_valid(target):
		hud.set_spectator_target_name("")
		return
	if target is Player:
		hud.set_spectator_target_name("PLAYER %d" % target.network_peer_id)
	elif target is Bot:
		hud.set_spectator_target_name("BOT %d" % target.network_id)
	else:
		hud.set_spectator_target_name("SPECTATOR")

func spectator_next() -> void:
	if not is_instance_valid(spectator):
		return
	_set_spectator_target(_find_spectator_target(1))

func spectator_previous() -> void:
	if not is_instance_valid(spectator):
		return
	_set_spectator_target(_find_spectator_target(-1))

func _start_spectator_camera() -> void:
	if is_instance_valid(spectator):
		return
	if not is_instance_valid(player) or not is_instance_valid(player.camera):
		return
	spectator = Camera3D.new()
	world.add_child(spectator)
	spectator.global_transform = player.camera.global_transform
	spectator.make_current()
	_set_spectator_target(_find_spectator_target(1))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _check_resolution() -> void:
	if not match_active:
		return

	# In a network match the host is the only authority allowed
	# to decide the outcome. Clients only receive the result RPC.
	if networked_match and not NetworkManager.is_host:
		return

	if is_cs:
		var living: Array[int] = [0, 0]
		var health_sum: Array[float] = [0.0, 0.0]

		for actor in actors:
			if actor.alive:
				living[actor.team] += 1
				health_sum[actor.team] += actor.health

		var winner: int = Rules.cs_winner(
			living,
			health_sum,
			elapsed >= Rules.CS_ROUND_SECONDS
		)

		if winner == -2:
			return

		match_active = false

		if winner >= 0:
			score[winner] += 1

		var final_match: bool = (
			score[0] >= Rules.CS_ROUNDS_TO_WIN
			or score[1] >= Rules.CS_ROUNDS_TO_WIN
		)

		if final_match:
			var title: String = "TEAM VICTORY" if score[0] > score[1] else "TEAM DEFEAT"
			_finish_match(title)
		else:
			round_number += 1
			intermission = 3.0
			network_round_pending = true

			if networked_match and NetworkManager.is_host:
				network_round_state.rpc(
					score[0],
					score[1],
					round_number,
					intermission
				)

	else:
		var survivors: Array[Node3D] = []

		for actor in actors:
			if actor.alive:
				survivors.append(actor)

		if survivors.size() <= 1:
			var title: String = "MATCH COMPLETE"

			if survivors.size() == 1 and survivors[0] == player:
				title = "LAST SURVIVOR — VICTORY"

			_finish_match(title)


@rpc("authority", "reliable", "call_remote")
func network_round_state(
	score_zero: int,
	score_one: int,
	next_round: int,
	delay: float
) -> void:
	if not networked_match:
		return

	if multiplayer.get_remote_sender_id() != 1:
		return

	score[0] = score_zero
	score[1] = score_one
	round_number = next_round
	intermission = maxf(delay, 0.0)
	network_round_pending = true
	match_active = false


@rpc("authority", "reliable", "call_remote")
func network_match_result(
	title: String,
	score_zero: int,
	score_one: int,
	final_kills: int
) -> void:
	if not networked_match:
		return

	if multiplayer.get_remote_sender_id() != 1:
		return

	if network_resolution_sent:
		return

	network_resolution_sent = true
	score[0] = score_zero
	score[1] = score_one
	kills = final_kills
	match_active = false
	intermission = 0
	network_round_pending = false

	_show_network_match_result(title)


func _show_network_match_result(title: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var detail: String = (
		"Team score %d : %d" % [score[0], score[1]]
		if is_cs
		else "%d eliminations" % kills
	)

	var rating_text: String = "Offline bot practice • no competitive rating"

	if ranked:
		var won: bool = title.contains("VICTORY")
		var rating_key: String = "cs_rating" if is_cs else "br_rating"
		var delta: int = Rules.rating_delta(mode_id, won)
		var rating: int = clampi(
			int(settings.data.get(rating_key, 1000)) + delta,
			0,
			5000
		)
		settings.data[rating_key] = rating
		settings.save()
		rating_text = "Local %s rating %d (%+d) • offline practice" % [
			"CS" if is_cs else "BR",
			rating,
			delta
		]

	hud.show_result(title + "\\n" + detail + "\\n" + rating_text)


func _finish_match(title: String) -> void:
	if networked_match:
		if not NetworkManager.is_host:
			return

		if network_resolution_sent:
			return

		network_resolution_sent = true
		match_active = false
		intermission = 0
		network_round_pending = false

		if network_room_session_id > 0:
			NetworkManager.finish_match_room(network_room_session_id)

		# Host displays the same authoritative result locally.
		_show_network_match_result(title)

		# Every connected client receives exactly the same result.
		for peer_id in multiplayer.get_peers():
			network_match_result.rpc_id(
				peer_id,
				title,
				score[0],
				score[1],
				kills
			)
		return

	# Offline match behavior remains local.
	match_active = false
	intermission = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var detail: String = (
		"Team score %d : %d" % [score[0], score[1]]
		if is_cs
		else "%d eliminations" % kills
	)

	var rating_text: String = "Offline bot practice • no competitive rating"

	if ranked:
		var won: bool = title.contains("VICTORY")
		var rating_key: String = "cs_rating" if is_cs else "br_rating"
		var delta: int = Rules.rating_delta(mode_id, won)
		var rating: int = clampi(
			int(settings.data.get(rating_key, 1000)) + delta,
			0,
			5000
		)
		settings.data[rating_key] = rating
		rating_text = "Local %s rating %d (%+d) • offline practice" % [
			"CS" if is_cs else "BR",
			rating,
			delta
		]

	hud.show_result(title + "\\n" + detail + "\\n" + rating_text)

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
	var radar_allies: Array[Vector3] = []
	hud.update_radar(player.position, player.yaw, zone_radius, arena.extent, radar_allies, is_cs)

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
