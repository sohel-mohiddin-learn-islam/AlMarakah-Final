extends SceneTree
## CI render smoke test. These screenshots are not a phone performance benchmark.
var game: Node3D
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute("res://build/screenshots")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _capture("lobby")
	game.hud.show_settings()
	await _capture("settings")
	game.hud.show_editor()
	await _capture("hud-editor")
	for map_id in 2:
		for mode in ["br", "cs"]:
			game.start_match(mode, map_id)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			for actor in game.actors:
				actor.set_physics_process(false)
			await _capture("%s-map-%d" % [mode, map_id])
	game.return_to_menu()
	game.queue_free()
	await process_frame
	print("ALMARAKAH RENDER SMOKE: %d failures" % failures)
	quit(1 if failures else 0)

func _capture(filename: String) -> void:
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		failures += 1
		push_error("No rendered image for " + filename)
		return
	if image.save_png("res://build/screenshots/%s.png" % filename) != OK:
		failures += 1
		push_error("Unable to save screenshot " + filename)
