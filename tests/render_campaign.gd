extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720,1600 if OS.get_cmdline_user_args().has("--tall") else 1280)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	await process_frame
	if OS.get_cmdline_user_args().has("--playing"):
		game.start_round()
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var path := "res://docs/campaign-0.1.5.png"
	if OS.get_cmdline_user_args().has("--playing"): path = "res://docs/gameplay-0.1.5.png"
	path = path.trim_suffix(".png") + "-" + str(viewport.size.y) + ".png"
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	quit()
