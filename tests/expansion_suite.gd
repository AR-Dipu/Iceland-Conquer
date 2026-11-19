extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	seed(7016)
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = "user://expansion_test_"+Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	for id in ["bgd","ind","lka","jpn","isl"]:
		game.campaign.starting = id
		game.selected_country = id
		game.choose_country()
		game.difficulty = 0
		game.start_round()
		var initial: float = 0
		for team in range(1,game.actors.size()): initial += game.territory.fractions[team]
		var capture_count: Array[int] = [0]
		var per_team: Array[int] = []
		var recent_travel: Array[float] = []
		per_team.resize(game.actors.size())
		recent_travel.resize(game.actors.size())
		game.territory.captured.connect(func(team: int,_gain: float,_point: Vector2) -> void:
			if team > 0:
				capture_count[0] += 1
				per_team[team] += 1)
		# Uncontested expansion: exercise real steering, movement and capture,
		# without opponent elimination hiding an expansion failure.
		for tick in 7200:
			for actor in game.actors.slice(1):
				var direction: Vector2 = game.brains[actor.team].steer(actor,game.territory,game.current_map,1.0/60)
				actor.advance(direction,1.0/60,game.island)
				if tick >= 6600: recent_travel[actor.team] += actor.previous.distance_to(actor.position)
				game._update_trail(actor)
			if tick%600 == 0: await process_frame
		var final: float = 0
		for team in range(1,game.actors.size()): final += game.territory.fractions[team]
		print("EXPANSION ",id," initial=",initial," final=",final," captures=",capture_count[0]," per_team=",per_team," recent_travel=",recent_travel)
		assert(final > initial+0.005,"No useful opponent land gain: "+id)
		assert(capture_count[0] >= 3,"Too few captures: "+id)
		for team in range(1,game.actors.size()):
			assert(per_team[team] > 0,"Opponent never captured land: "+id)
			assert(recent_travel[team] > 25,"Opponent persistently stalled: "+id)
	game.queue_free()
	await process_frame
	print("RESULT 5 two-minute expansion simulations passed")
	quit()
