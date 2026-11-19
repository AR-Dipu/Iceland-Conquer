extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = "user://minimap_test_"+Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(game)
	await process_frame
	game.start_round()
	game.set_physics_process(false)
	var before: int = game.territory.revision
	var snapshot: Array = game.territory.mesh_snapshot()
	assert(snapshot.size() == game.actors.size())
	for team in snapshot.size():
		assert(snapshot[team].pieces.size() == game.territory.regions[team].size())
		for i in snapshot[team].pieces.size(): assert(snapshot[team].pieces[i].polygon == game.territory.regions[team][i])
	game.territory.regions[1] = []
	game.territory._update_fractions()
	assert(game.territory.revision > before and game.territory.mesh_snapshot()[1].pieces.is_empty())
	for size in [Vector2i(720,1280),Vector2i(720,1600)]:
		root.size = size
		game.camera.zoom = Vector2.ONE*1.3
		game.camera.force_update_scroll()
		var footprint: PackedVector2Array = game.hud.minimap_camera_polygon()
		var inverse: Transform2D = game.get_viewport().get_canvas_transform().affine_inverse()
		var transform: Transform2D = game.hud.minimap_transform()
		assert(footprint[0].is_equal_approx(transform*(inverse*Vector2.ZERO)))
		assert(footprint[2].is_equal_approx(transform*(inverse*Vector2(game.get_viewport_rect().size))))
	game.queue_free()
	await process_frame
	print("RESULT shared geometry and viewport footprint checks passed")
	quit()
