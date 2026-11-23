extends SceneTree
func rectangle(x: float,y: float,w: float,h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x,y),Vector2(x+w,y),Vector2(x+w,y+h),Vector2(x,y+h)])
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = "user://hunter_"+Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(game)
	game.start_round()
	game.set_physics_process(false)
	var map := CountryMap.new()
	map.outline = rectangle(0,0,1000,1000)
	map.land_bounds = Rect2(0,0,1000,1000)
	map._build_navigation()
	map.built = true
	var tm: TerritoryManager = game.territory
	tm.island = map.outline
	tm.island_area = 1000000
	tm.regions = [[rectangle(800,800,100,100)],[rectangle(50,50,200,200)],[rectangle(800,650,100,100)],[rectangle(50,800,100,100)]]
	tm._update_fractions()
	for other in game.actors:
		other.position = Vector2(850,850)
		other.velocity = Vector2.ZERO
		other.protection = 0
		other.trail.clear()
	var actor: ConquerCharacter = game.actors[1]
	var target: ConquerCharacter = game.actors[0]
	actor.position = Vector2(400,400)
	actor.trail.points = PackedVector2Array([Vector2(250,100),Vector2(400,100),Vector2(400,400)])
	var brain: BotBrain = game.brains[1]
	brain.reset()
	brain.wait = 0
	brain.has_plan = true
	brain.planned_return = Vector2(100,200)
	brain.expected_fraction = 0.005
	brain.waypoints = [Vector2(600,400),Vector2(600,200),Vector2(100,200)]
	var conquest := brain.waypoints.duplicate()
	target.position = Vector2(500,500)
	target.trail.points = PackedVector2Array([Vector2(450,250),Vector2(450,500)])
	brain._tactics(actor,tm,map)
	assert(brain.attack_target == target and brain.interrupted_route == conquest)
	target.trail.clear()
	actor.position = Vector2(450,400)
	actor.trail.points.append(actor.position)
	brain._tactics(actor,tm,map)
	assert(brain.attack_target == null and brain.has_plan and brain.waypoints == conquest)
	assert(brain.interrupted_route.is_empty())
	var closure := actor.trail.points.duplicate()
	closure.append_array(PackedVector2Array(conquest))
	var excursion := tm.closed_excursion(actor.team,closure)
	assert(BotBrain.overlap_ratio(excursion) <= 0.1)
	var preview := tm.preview_capture(actor.team,excursion)
	assert(preview.ok and preview.area > 10000)
	assert(tm.capture(actor.team,excursion,PackedVector2Array()))
	# A distant small inheritance must include the journey back to safety in
	# its opportunity cost, rather than discard a broad productive loop.
	tm.regions[1] = [rectangle(50,50,200,200)]
	tm._update_fractions()
	brain.reset()
	brain.has_plan = true
	brain.expected_fraction = 0.25
	brain.planned_return = Vector2(100,200)
	brain.waypoints = conquest.duplicate()
	actor.position = Vector2(400,400)
	actor.trail.points = PackedVector2Array([Vector2(250,100),Vector2(400,100),Vector2(400,400)])
	var distant: ConquerCharacter = game.actors[2]
	distant.position = Vector2(800,100)
	distant.trail.points = PackedVector2Array([Vector2(850,700),Vector2(700,600),Vector2(700,200)])
	brain._tactics(actor,tm,map)
	assert(brain.has_plan and brain.attack_target == null and brain.waypoints == conquest)
	# Positive closing velocity alone is not evidence of an imminent cut:
	# this rival is moving across the trail and cannot beat the safe return.
	distant.position = Vector2(560,450)
	distant.velocity = Vector2(0,-91)
	brain._tactics(actor,tm,map)
	assert(brain.tactical_action != "defend" and brain.has_plan and brain.waypoints == conquest)
	brain.has_plan = true
	brain.waypoints = conquest.duplicate()
	brain._stash_capture(tm,actor.team)
	tm.regions[actor.team] = []
	assert(not brain._resume_capture(actor,tm,map))
	brain.interrupted_route = conquest.duplicate()
	brain.reset()
	assert(brain.interrupted_route.is_empty())
	game.queue_free()
	await process_frame
	print("RESULT productive route resumption, proportional attack/return costs, observed threats and stale-route rejection passed")
	quit()
