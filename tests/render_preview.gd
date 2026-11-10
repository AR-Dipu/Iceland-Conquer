extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var country: String = "bgd"
	var overview: bool = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--country="):
			country = arg.trim_prefix("--country=")
		overview = overview or arg == "--overview"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.selector.select(country)
	game.start_round()
	if overview:
		var size: Vector2 = game.current_map.land_bounds.size
		game.camera.zoom = Vector2.ONE * minf(620 / size.x, 910 / size.y)
		game.camera.position = game.current_map.land_bounds.get_center() - Vector2(0, 90 / game.camera.zoom.x)
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://docs/" + ("overview-" if overview else "gameplay-") + country + ".png"
	var error: Error = root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("PREVIEW: ", path, " error=", error)
	quit(0 if error == OK else 1)
