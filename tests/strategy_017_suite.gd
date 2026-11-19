extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var report: Array = []
	for id in ["bgd","ind","lka","jpn","isl"]:
		for legacy in [true,false]:
			seed(7017)
			var game = load("res://scenes/main.tscn").instantiate()
			game.profile_path = "user://strategy_test_"+Crypto.new().generate_random_bytes(8).hex_encode()
			root.add_child(game)
			await process_frame
			game.set_physics_process(false)
			game.campaign.starting = id
			game.selected_country = id
			game.start_round()
			for brain in game.brains: brain.legacy_planning = legacy
			var initial: float = 0
			for team in range(1,game.actors.size()): initial += game.territory.fractions[team]
			var counts: Array[int] = [0,0,0,0]
			game.territory.captured.connect(func(team: int,_gain: float,_at: Vector2) -> void: counts[team] += 1)
			var two: float = 0
			var duration: int = 18000 if not OS.get_cmdline_user_args().has("--short") else 7200
			for tick in duration:
				if game.state != game.State.PLAYING:
					if two == 0:
						for team in range(1,game.actors.size()): two += game.territory.fractions[team]
					break
				for actor in game.actors.slice(1):
					var direction: Vector2 = game.brains[actor.team].steer(actor,game.territory,game.current_map,1.0/60)
					actor.advance(direction,1.0/60,game.island)
					game._update_trail(actor)
				if tick == 7199:
					for team in range(1,game.actors.size()): two += game.territory.fractions[team]
				if tick%600 == 0: await process_frame
			var final: float = 0
			for team in range(1,game.actors.size()): final += game.territory.fractions[team]
			var item := {"country":id,"legacy":legacy,"initial":initial,"two_minutes":two,"final":final,"captures":counts}
			report.append(item)
			print("STRATEGY ",JSON.stringify(item))
			game.queue_free()
			await process_frame
	var file := FileAccess.open("res://docs/strategy-0.1.7-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("RESULT 10 matched strategy simulations completed")
	quit()
