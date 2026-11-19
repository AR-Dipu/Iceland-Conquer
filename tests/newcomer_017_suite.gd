extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	seed(170)
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = "user://newcomer_test_"+Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	assert(not game.selector.can_play(),"Fresh country must be explicitly selected")
	game.selector.first_choice_made = true
	game.selector.select("bgd")
	assert(game.selector.can_play())
	game.start_round()
	assert(not game.try_newcomer(),"Full roster")
	game.eliminate_bot(1)
	var old_count: int = game.actors.size()
	game.territory.fractions[0] = 0.4
	assert(not game.try_newcomer(),"40 percent boundary")
	game.territory._update_fractions()
	assert(game.try_newcomer(),"Vacancy fills on neutral land")
	assert(game.actors.size() == old_count+1 and not game.actors[1].active,"Fresh stable ID, no resurrection")
	var team: int = game.actors.size()-1
	assert(game.territory.owned(team,game.actors[team].position))
	for other in team:
		for p in game.territory.regions[other]:
			for q in game.territory.regions[team]: assert(Geometry2D.intersect_polygons(p,q).is_empty())
	game.eliminate_bot(2)
	var count_before: int = game.actors.size()
	game.arrival_elapsed = 29.8
	game._physics_process(0.1)
	assert(game.actors.size() == count_before,"No early arrival")
	game._physics_process(0.2)
	assert(game.actors.size() == count_before+1,"Arrival at 30 active seconds")
	game.pause_round()
	var elapsed: float = game.arrival_elapsed
	game._physics_process(60)
	assert(game.arrival_elapsed == elapsed,"Pause freezes arrival clock")
	assert(not game.try_newcomer(),"Paused")
	var frame: PackedVector2Array = game.hud.minimap_camera_polygon()
	var transform: Transform2D = game.hud.minimap_transform()
	var inverse: Transform2D = game.get_viewport().get_canvas_transform().affine_inverse()
	assert(frame[0].is_equal_approx(transform*(inverse*Vector2.ZERO)))
	game.start_round()
	assert(game.arrival_elapsed == 0 and game.actors.size() == 4)
	game.queue_free()
	await process_frame
	print("RESULT 13 newcomer/choice/minimap checks passed")
	quit()
