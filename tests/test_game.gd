extends SceneTree
const Rules = preload("res://scripts/rules.gd")
const Settings = preload("res://scripts/settings.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	# Headless defaults to a 64x64 window; exercise the real landscape layout.
	root.size = Vector2i(1280, 720)
	check(Rules.participant_count("br") == 50, "BR has 50 participants")
	check(Rules.participant_count("br_ranked") == 50, "BR ranked has 50 participants")
	check(Rules.participant_count("cs") == 8, "CS has eight participants")
	check(Rules.participant_count("cs_ranked") == 8, "CS ranked has eight participants")
	check(Rules.is_ranked("br_ranked") and not Rules.is_ranked("br_classic"), "ranked mode IDs are distinct")
	check(Rules.weapon_profile("smg")["magazine_size"] > Rules.weapon_profile("marksman")["magazine_size"], "loadouts expose distinct weapon profiles")
	check(Rules.radius_at(0, 125) == 125, "zone starts full sized")
	check(Rules.radius_at(25, 125) == 125, "zone grace period")
	check(Rules.radius_at(1000, 125) == 3, "zone has minimum radius")
	check(Rules.radius_at(100, 125) < Rules.radius_at(50, 125), "zone shrinks monotonically")
	check(not Rules.enemies(true, 0, 0), "CS teammates do not damage each other")
	check(Rules.enemies(false, 0, 0), "BR is free for all")
	check(Rules.cs_winner([4, 0], [400.0, 0.0], false) == 0, "CS team elimination")
	check(Rules.cs_winner([0, 0], [0.0, 0.0], false) == -1, "simultaneous elimination draw")
	check(Rules.cs_winner([4, 4], [400.0, 400.0], false) == -2, "CS ongoing")
	check(Rules.cs_winner([3, 2], [80.0, 200.0], true) == 0, "CS timeout compares survivors first")
	check(Rules.cs_winner([2, 2], [120.0, 180.0], true) == 1, "CS timeout health tie-break")
	check(Rules.cs_winner([4, 4], [400.0, 400.0], true) == -1, "timeout draw")
	var MatchRoomScript = load("res://scripts/match_room.gd")
	var room_test = MatchRoomScript.new()
	root.add_child(room_test)
	room_test.setup(101, "br_classic", 0, [1, 2, 3], 50)
	check(room_test.session_id == 101, "MatchRoom stores session ID")
	check(room_test.mode_id == "br_classic", "MatchRoom stores mode")
	check(room_test.bot_count == 47, "MatchRoom calculates BR bot count")
	check(room_test.human_peer_ids.size() == 3, "MatchRoom stores BR humans")
	check(room_test.is_active(), "locked MatchRoom is active")
	room_test.state = "finished"
	check(not room_test.is_active(), "finished MatchRoom is inactive")
	room_test.queue_free()
	await process_frame
	var NetworkManagerScript = load("res://scripts/network_manager.gd")
	var matchmaking = NetworkManagerScript.new()
	root.add_child(matchmaking)

        var room_lock_events: Array = []
        matchmaking.room_match_locked.connect(func(session_id: int, mode: String, map_index: int, human_ids: Array) -> void:
                room_lock_events.append({
                        "session_id": session_id,
                        "mode": mode,
                        "map": map_index,
                        "humans": human_ids.duplicate()
                })
        )
	matchmaking.is_host = true
	matchmaking.connected = true
	check(not matchmaking.matchmaking_active, "matchmaking starts idle")
	matchmaking.request_matchmaking_ready("br_classic", 0)
	check(matchmaking.matchmaking_active, "START opens matchmaking window")
	check(matchmaking.matchmaking_ready.size() == 1, "START adds exactly one ready player")
	check(matchmaking.matchmaking_mode == "br_classic", "matchmaking locks selected mode")
	matchmaking.matchmaking_time_left = 0.01
	matchmaking._process(0.02)
	check(not matchmaking.matchmaking_active, "matchmaking closes after lock")
	check(matchmaking.matchmaking_ready.is_empty(), "ready queue clears after lock")
	var br_room: Dictionary = matchmaking.get_match_room(matchmaking.active_match_session_id)
	check(br_room.get("mode", "") == "br_classic", "locked BR room stores mode")
	check(br_room.get("bot_count", -1) == 49, "one BR player gets 49 bots")
	check(br_room.get("human_peer_ids", []).size() == 1, "BR room stores one human")
	check(matchmaking.is_match_room_active(matchmaking.active_match_session_id), "locked room is active")
        check(room_lock_events.size() == 1, "room lock signal emitted once")
        check(room_lock_events[0]["session_id"] == matchmaking.active_match_session_id, "room lock signal has session ID")
        check(room_lock_events[0]["mode"] == "br_classic", "room lock signal has BR mode")
        check(room_lock_events[0]["map"] == 0, "room lock signal has map")
        check(room_lock_events[0]["humans"].size() == 1, "room lock signal has human roster")
	check(not matchmaking.is_match_room_active(999999), "unknown room is inactive")
	matchmaking.match_rooms[matchmaking.active_match_session_id].state = "finished"
	check(not matchmaking.is_match_room_active(matchmaking.active_match_session_id), "finished room is inactive")
	var room_game = load("res://scenes/main.tscn").instantiate()
	root.add_child(room_game)
	await process_frame
	room_game.networked_match = true
	room_game.network_room_session_id = matchmaking.active_match_session_id
	check(room_game.is_in_network_room(), "Game recognizes active room session")
	room_game.network_room_session_id = 0
	check(not room_game.is_in_network_room(), "Game rejects empty room session")
	room_game.queue_free()
	await process_frame
	matchmaking.matchmaking_ready.clear()
	matchmaking.matchmaking_active = false
	matchmaking.matchmaking_session_id = 0
	matchmaking.request_matchmaking_ready("cs_classic", 0)
	matchmaking.matchmaking_time_left = 0.01
	matchmaking._process(0.02)
	var cs_room: Dictionary = matchmaking.get_match_room(matchmaking.active_match_session_id)
	check(cs_room.get("mode", "") == "cs_classic", "locked CS room stores mode")
	check(cs_room.get("bot_count", -1) == 7, "one CS player gets 7 bots")
	check(cs_room.get("human_peer_ids", []).size() == 1, "CS room stores one human")
	var room_a = matchmaking.create_match_room(201, "br_classic", 0, [10])
	var room_b = matchmaking.create_match_room(202, "br_classic", 1, [20, 21])
	check(room_a != room_b, "two match rooms are separate objects")
	check(matchmaking.get_match_room(201).get("bot_count", -1) == 49, "room A keeps 49 bots")
	check(matchmaking.get_match_room(202).get("bot_count", -1) == 48, "room B keeps 48 bots")
	check(matchmaking.get_match_room(201).get("map", -1) == 0, "room A keeps its map")
	check(matchmaking.get_match_room(202).get("map", -1) == 1, "room B keeps its map")
	matchmaking.queue_free()
	await process_frame
	var prefs = Settings.new()
	prefs.storage_path = "user://almarakah_test_settings.json"
	prefs.data.camera_sensitivity = 2.2
	prefs.data.hud_positions = {"fire": [0.82, 0.68]}
	prefs.save()
	var loaded = Settings.new()
	loaded.storage_path = prefs.storage_path
	loaded.load_settings()
	check(is_equal_approx(loaded.data.camera_sensitivity, 2.2), "settings round-trip")
	check(loaded.data.hud_positions.has("fire"), "HUD coordinates round-trip")
	var file = FileAccess.open(prefs.storage_path, FileAccess.WRITE)
	file.store_string("{broken json")
	file.close()
	loaded = Settings.new()
	loaded.storage_path = prefs.storage_path
	loaded.load_settings()
	check(loaded.data.camera_sensitivity == 1.0, "corrupt settings fall back safely")
	DirAccess.remove_absolute(prefs.storage_path)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(not game.match_active, "boot opens lobby")
	await _test_lobby_touch(game.hud)
	_test_hud(game.hud)
	game.start_match("ranked", 0)
	check(not game.match_active, "unknown mode cannot start a match")
	for ranked_mode in ["br_ranked", "cs_ranked"]:
		game.start_match(ranked_mode, 0)
		await physics_frame
		check(game.ranked and game.mode_id == ranked_mode, "%s starts as local ranked practice" % ranked_mode)
		check(game.actors.size() == Rules.participant_count(ranked_mode), "%s participant count" % ranked_mode)
		game.return_to_menu()
	for map_index in 2:
		for match_mode in ["br", "cs"]:
			game.start_match(match_mode, map_index)
			await physics_frame
			check(game.actors.size() == Rules.participant_count(match_mode), "actor count %s map %d" % [match_mode, map_index])
			check(game.arena._obstacles.size() > 10, "map scenery and cover built %s map %d" % [match_mode, map_index])
			var teams: Array[int] = [0, 0]
			for actor in game.actors:
				if game.is_cs:
					teams[actor.team] += 1
				var shape = CapsuleShape3D.new()
				shape.height = 1.8
				shape.radius = 0.38
				var query = PhysicsShapeQueryParameters3D.new()
				query.shape = shape
				query.transform.origin = actor.global_position + Vector3(0, 0.95, 0)
				query.collision_mask = 1
				var overlaps: Array = game.get_world_3d().direct_space_state.intersect_shape(query)
				check(overlaps.is_empty(), "spawn not inside cover %s map %d" % [match_mode, map_index])
			if game.is_cs:
				check(teams == [4, 4], "CS teams balanced")
			for frame in 45:
				await physics_frame
			check(game.player.position.y > -1.0, "player stays on ground")
			for actor in game.actors:
				actor.set_physics_process(false)
			if not game.is_cs:
				for i in range(1, game.actors.size()):
					game.actors[i].take_damage(1000, game.player)
				await process_frame
				check(not game.match_active, "BR ends with one survivor")
				check(game.kills == 49, "BR kill counter")
			else:
				for actor in game.actors:
					if actor.team == 1:
						actor.take_damage(1000, game.player)
				await process_frame
				check(game.score == [1, 0], "CS round increments score once")
				check(game.intermission > 0, "CS next round scheduled")
				game.return_to_menu()
				check(game.intermission == 0, "menu cancels pending round")
				check(game.actors.is_empty(), "menu clears actors")
	# Exercise reload, damage, friendly fire and collision raycasts in a real world.
	game.start_match("cs", 0)
	await physics_frame
	for actor in game.actors:
		actor.set_physics_process(false)
	var hero = game.player
	hero.ammo = 5
	hero.reserve = 10
	hero.reload_weapon()
	hero._physics_process(1.8)
	check(hero.ammo == 15 and hero.reserve == 0, "reload conserves available ammunition")
	var enemy = game.actors[4]
	hero.position = Vector3(0, 15, 0)
	enemy.position = Vector3(0, 15, -8)
	await physics_frame
	game.fire_ray(hero.position + Vector3(0, 1.1, 0), Vector3.FORWARD, hero, 26, 30)
	check(enemy.health == 174, "hitscan damages enemy")
	var ally = game.actors[1]
	ally.position = Vector3(0, 15, -4)
	await physics_frame
	game.fire_ray(hero.position + Vector3(0, 1.1, 0), Vector3.FORWARD, hero, 26, 30)
	check(ally.health == 200 and enemy.health == 174, "teammate blocks ray without friendly damage")
	ally.position.x = 20
	var wall = StaticBody3D.new()
	wall.collision_layer = 1
	var wall_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(3, 3, 1)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	game.world.add_child(wall)
	wall.position = Vector3(0, 16, -4)
	await physics_frame
	game.fire_ray(hero.position + Vector3(0, 1.1, 0), Vector3.FORWARD, hero, 26, 30)
	check(enemy.health == 174, "solid cover blocks hitscan damage")
	hero.take_damage(1000, enemy)
	check(is_instance_valid(game.spectator) and game.spectator.current, "player death activates spectator")
	for actor in game.actors:
		if actor.team == 1:
			actor.take_damage(1000)
	await process_frame
	game._physics_process(3.1)
	check(game.match_active and game.player.alive, "CS next round respawns player")
	check(game.score == [1, 0] and game.round_number == 2, "CS next round preserves score")
	for win in 3:
		for actor in game.actors:
			actor.set_physics_process(false)
			if actor.team == 1:
				actor.take_damage(1000)
		await process_frame
		if win < 2:
			game._physics_process(3.1)
	check(game.score == [4, 0] and not game.match_active, "CS finishes at four wins")
	check(game.hud.screen == "result", "match completion displays result")
	game.return_to_menu()
	await process_frame
	game.queue_free()
	await process_frame
	print("ALMARAKAH TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _test_lobby_touch(hud: CanvasLayer) -> void:
	# Exercise real viewport dispatch and mouse emulation, not just helper methods.
	await process_frame
	var settings_button: Button = null
	for button in hud.lobby.find_children("*", "Button", true, false):
		if button.text == "Settings & HUD":
			settings_button = button
	check(settings_button != null, "lobby exposes settings button")
	if settings_button == null:
		return
	hud.lobby.get_child(0).ensure_control_visible(settings_button)
	await process_frame
	var event = InputEventScreenTouch.new()
	event.index = 0
	event.position = root.get_final_transform() * settings_button.get_global_rect().get_center()
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	check(hud.screen == "settings", "real touch activates lobby settings button")
	hud.show_lobby()

func _test_hud(hud: CanvasLayer) -> void:
	check(hud.screen == "lobby" and hud.lobby.visible, "HUD opens lobby")
	check(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"), "touch can operate standard lobby buttons")
	var saved: Dictionary = hud.settings.data.duplicate(true)
	hud.settings.data.hud_positions = {}
	hud.show_match()
	var stick: Vector2 = hud.pads.move.get_global_rect().get_center() + Vector2(40, 0)
	var fire: Vector2 = hud.pads.fire.get_global_rect().get_center()
	check(hud._touch_start(11, stick), "joystick takes a touch")
	check(hud._touch_start(12, hud.root.size * Vector2(0.55, 0.4)), "camera takes independent touch")
	check(hud._touch_start(13, fire), "fire takes third simultaneous touch")
	check(hud.firing and hud.move_vector.x > 0.1 and hud.touches.size() == 3, "move look and fire coexist")
	var drag = InputEventScreenDrag.new()
	drag.index = 12
	drag.relative = Vector2(20, -10)
	hud._input(drag)
	check(hud.look_delta == Vector2(20, -10), "camera drag accumulates look")
	hud._touch_end(12)
	check(hud.firing and hud.move_vector.x > 0.1, "releasing look preserves other fingers")
	hud._touch_start(14, fire)
	hud._touch_end(14)
	check(hud.firing, "second fire finger cannot release owner's fire")
	var canceled = InputEventScreenTouch.new()
	canceled.index = 13
	canceled.canceled = true
	hud._input(canceled)
	check(not hud.firing, "canceled fire touch releases firing")
	hud._touch_end(11)
	check(hud.move_vector == Vector2.ZERO, "joystick release stops movement")
	hud._touch_start(15, hud.pads.ads.get_global_rect().get_center())
	hud._touch_end(15)
	check(hud.aiming, "ADS toggles on tap")
	hud._touch_start(16, fire)
	hud._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not hud.firing and not hud.aiming and hud.touches.is_empty() and hud.look_delta == Vector2.ZERO, "focus loss clears all touch state")
	hud.show_editor()
	hud._drag_pad("fire", Vector2(-100, 99999))
	check(hud.settings.data.hud_positions.fire == [0.05, 0.92], "HUD editor clamps layout coordinates")
	for scale in [0.7, 1.5]:
		hud.settings.data.hud_scale = scale
		for size in [Vector2(1280, 720), Vector2(1600, 720)]:
			hud.root.size = size
			hud._layout_pads()
			for pad in hud.pads.values():
				check(Rect2(Vector2.ZERO, size).encloses(pad.get_global_rect()), "HUD pad remains inside screen")
	hud.settings.data = saved
	hud.root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.show_result("Test result")
	check(hud.result_panel.visible and not hud.match_ui.visible, "result hides touch controls")
	hud.show_lobby()
