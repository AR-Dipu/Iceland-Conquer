extends SceneTree
func rectangle(x: float,y: float,w: float,h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x,y),Vector2(x+w,y),Vector2(x+w,y+h),Vector2(x,y+h)])
func _initialize() -> void:
	run.call_deferred()
func fixture():
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = "user://winning_ai_"+Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(game)
	game.start_round()
	game.set_physics_process(false)
	var country := CountryMap.new()
	country.outline = rectangle(0,0,1000,1000)
	country.land_bounds = Rect2(0,0,1000,1000)
	country.center = Vector2(500,500)
	country._build_navigation()
	country.built = true
	game.current_map = country
	game.island = country.outline
	game.territory.island = country.outline
	game.territory.island_area = 1000000
	game.territory.regions = [[rectangle(800,800,100,100)],[rectangle(50,50,200,200)],[rectangle(800,650,100,100)],[rectangle(50,800,100,100)]]
	game.territory._update_fractions()
	for actor in game.actors:
		actor.protection = 0
		actor.position = [Vector2(500,500),Vector2(100,100),Vector2(700,500),Vector2(100,850)][actor.team]
		actor.previous = actor.position
		actor.velocity = Vector2.ZERO
		game.brains[actor.team].wait = 0
	return game
func run() -> void:
	assert(BotBrain.overlap_ratio(PackedVector2Array([Vector2(100,100),Vector2(400,100),Vector2(100,100)])) > 0.1)
	assert(BotBrain.overlap_ratio(PackedVector2Array([Vector2(100,100),Vector2(400,100),Vector2(400,400),Vector2(100,200)])) < 0.1)
	for victim in [0,2]:
		var game = fixture()
		game.actors[victim].trail.points = PackedVector2Array([Vector2(200,50),Vector2(200,250)])
		var actor: ConquerCharacter = game.actors[1]
		for tick in 140:
			var direction: Vector2 = game.brains[1].steer(actor,game.territory,game.current_map,1.0/60)
			actor.advance(direction,1.0/60,game.island)
			game._resolve_attacks()
			if game.state == game.State.DEFEATED or not game.actors[victim].active: break
		assert(game.state == game.State.DEFEATED if victim == 0 else not game.actors[victim].active,"AI must execute a real trail cut")
		print("REAL CUT PASS victim=",victim)
		game.queue_free()
		await process_frame
	var game = fixture()
	var brain: BotBrain = game.brains[1]
	var actor: ConquerCharacter = game.actors[1]
	actor.position = Vector2(400,400)
	actor.trail.points = PackedVector2Array([Vector2(100,100),Vector2(400,100),Vector2(400,400)])
	brain.waypoints = [Vector2(500,400),Vector2(500,100),Vector2(100,100)]
	var route: Array = brain.waypoints.duplicate()
	game.actors[0].position = Vector2(300,200)
	game.actors[0].velocity = Vector2(-91,0)
	brain._tactics(actor,game.territory,game.current_map)
	assert(brain.waypoints == route and brain.tactical_action != "defend","Harmless nearby actor must not abort loop")
	game.actors[0].position = Vector2(390,200)
	game.actors[0].velocity = Vector2(91,0)
	brain._tactics(actor,game.territory,game.current_map)
	assert(brain.tactical_action == "defend")
	route = brain.waypoints.duplicate()
	brain._tactics(actor,game.territory,game.current_map)
	assert(brain.waypoints == route and brain.defensive_returns == 1,"Defensive route must stay stable")
	var hole := rectangle(400,400,200,100)
	actor.trail.clear()
	brain.reset()
	actor.position = Vector2(100,100)
	game.actors[0].position = Vector2(500,500)
	game.actors[0].velocity = Vector2.ZERO
	game.actors[0].trail.points = PackedVector2Array([Vector2(200,50),Vector2(200,250)])
	game.actors[2].trail.points = PackedVector2Array([Vector2(180,50),Vector2(180,250)])
	game.territory.fractions[0] = 0.8
	brain._tactics(actor,game.territory,game.current_map)
	assert(brain.attack_target == game.actors[0],"Prioritize a vulnerable leading rival")
	game.actors[0].protection = 3
	game.actors[2].protection = 3
	brain._tactics(actor,game.territory,game.current_map)
	assert(brain.attack_target == null,"Protected targets cancel pursuit")
	game.actors[0].trail.clear()
	game.actors[2].trail.clear()
	game.territory.regions = [[],IslandGeometry.subtract(game.island,hole),[],[]]
	for opponent in game.actors:
		if opponent.team != actor.team: opponent.active = false
	game.territory._update_fractions()
	assert(game.territory.fractions[1] < 0.99)
	brain.reset()
	brain.wait = 0
	actor.trail.clear()
	actor.velocity = Vector2.ZERO
	for tick in 3600:
		if game.state != game.State.PLAYING: break
		var direction: Vector2 = brain.steer(actor,game.territory,game.current_map,1.0/60)
		actor.advance(direction,1.0/60,game.island)
		game._update_trail(actor)
	assert(game.winning_team == 1 and game.state == game.State.ROUND_OVER,"Final pocket must cause actual AI win")
	game.queue_free()
	await process_frame
	game = fixture()
	actor = game.actors[1]
	brain = game.brains[1]
	game.actors[0].position = Vector2(850,850)
	game.actors[3].active = false
	game.actors[2].position = Vector2(310,150)
	game.territory.regions[2] = [rectangle(290,130,40,40)]
	game.territory._update_fractions()
	game.telemetry.enabled = true
	for tick in 1800:
		if not game.actors[2].active: break
		game.territory.begin_planning_frame()
		var direction: Vector2 = brain.steer(actor,game.territory,game.current_map,1.0/60)
		actor.advance(direction,1.0/60,game.island)
		game._update_trail(actor)
	assert(game.telemetry.cuts_by_bots("encirclement") == 1,"AI must encircle an opponent without a trail")
	game.queue_free()
	await process_frame
	print("RESULT loop overlap, real cuts, commitment, defense and AI victory passed")
	quit()
