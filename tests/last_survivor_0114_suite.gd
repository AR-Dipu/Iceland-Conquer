extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func rectangle(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x,y),Vector2(x+w,y),Vector2(x+w,y+h),Vector2(x,y+h)])

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = "user://last_survivor_" + Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_round()
	var territory: TerritoryManager = game.territory
	territory.island = rectangle(0,0,600,500)
	territory.island_area = IslandGeometry.area(territory.island)
	territory.regions = [[rectangle(30,50,120,250)],[rectangle(200,90,25,25)],
		[rectangle(250,115,25,25)],[rectangle(430,350,30,30)]]
	territory._update_fractions()
	var trail := PackedVector2Array([Vector2(150,70),Vector2(350,70),Vector2(350,250),Vector2(150,250)])
	game.actors[1].position = Vector2(210,100)
	game.actors[2].position = Vector2(275,175)
	game.actors[3].position = Vector2(350,150)
	game.telemetry.enabled = true
	assert(territory.capture(0,trail,PackedVector2Array()))
	assert(not game.actors[1].active and not game.actors[2].active and game.actors[3].active)
	assert(not territory.newly_encircles(Vector2(100,100)))
	assert(game.running and territory.fractions[0] < 0.99)
	assert(territory.regions[1].is_empty() and territory.regions[2].is_empty())
	territory.fractions[0] = 1.0
	game._check_victory(0)
	assert(game.running and game.winning_team == -1)
	game.eliminate_bot(3)
	game._check_victory(0)
	assert(game.running)
	territory.regions[0] = [territory.island]
	territory._update_fractions()
	game.arrival_elapsed = 30.0
	game._physics_process(1.0/60)
	assert(game.state == game.State.ROUND_OVER and game.winning_team == 0 and game.newcomer_serial == 0)
	game.campaign.conquered.clear()
	game.start_round()
	assert(game.actors[1].movement_speed() == 210 and game.actors[1].movement_acceleration() == 1600)
	game._defeat_player(1,"encirclement")
	assert(game.state == game.State.DEFEATED and game.winning_team == -1)
	game._revive_player()
	assert(game.running and game.actors[0].active)
	game._defeat_player(1,"encirclement")
	game.choose_country()
	assert(game.state == game.State.SELECTION and game.winning_team == -1)
	game.queue_free()
	await process_frame
	print("RESULT capture encirclement, boundary exclusion, dual victory, arrival ordering and revival passed")
	quit()
