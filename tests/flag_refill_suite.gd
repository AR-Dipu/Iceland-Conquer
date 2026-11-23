extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	seed(117)
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = "user://flag_refill_test_" + Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	for id in ["bgd", "ind", "jpn", "isl", "chl"]:
		assert(game.load_country(id))
		assert(game.world.flag_mesh != null and game.world.flag_texture != null, id)
		var arrays: Array = game.world.flag_mesh.surface_get_arrays(0)
		assert(arrays[Mesh.ARRAY_VERTEX] == game.current_map.outline, id)
		assert(game.world.border_contour[0] == game.world.border_contour[-1], id)
		assert(game.actors[0].visual_world_position() == game.actors[0].position, id)
		print("FLAG PASS ", id)
	game.selector.first_choice_made = true
	game.selector.select("bgd")
	for difficulty in 3:
		game.difficulty = difficulty
		game.start_round()
		assert(game.actors.size() == 4 + difficulty * 2)
		game._tick_refills(120.0)
		assert(is_zero_approx(game.arrival_elapsed))
		game.eliminate_bot(1)
		game.eliminate_bot(2)
		game._tick_refills(19.9)
		assert(not game.actors[1].active)
		game.pause_round()
		game._physics_process(20.0)
		assert(is_equal_approx(game.arrival_elapsed, 19.9))
		game._set_state(game.State.PLAYING)
		game._tick_refills(0.11)
		for retry in 8:
			if game.actors[1].active: break
			assert(not game.actors[2].active and is_zero_approx(game.arrival_elapsed))
			game._tick_refills(20.0)
		assert(game.actors[1].active and not game.actors[2].active)
		var saved: Array = game.territory.regions[0]
		game.territory.regions[0] = [game.island]
		game._tick_refills(20.0)
		assert(not game.actors[2].active and is_zero_approx(game.arrival_elapsed), "Unsafe attempt restarts the interval")
		game.territory.regions[0] = saved
		for interval in 8:
			if game.actors[2].active: break
			game._tick_refills(19.9)
			assert(not game.actors[2].active, "No batched or early refill")
			game._tick_refills(0.11)
		assert(game.actors[2].active and not game._has_rival_vacancy(), "2nd arrival: difficulty=%s live=%s clock=%s" % [difficulty, game.actors.map(func(a): return a.active), game.arrival_elapsed])
		assert(is_zero_approx(game.arrival_elapsed))
	game.queue_free()
	await process_frame
	print("RESULT five flag terrain checks and refills at every difficulty passed")
	quit()


