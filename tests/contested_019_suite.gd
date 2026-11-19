extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var report: Array = []
	for id in ["bgd","isl"]:
		for old in [true,false]:
			seed(190)
			var game = load("res://scenes/main.tscn").instantiate()
			game.profile_path = "user://contest_"+Crypto.new().generate_random_bytes(8).hex_encode()
			root.add_child(game)
			await process_frame
			game.set_physics_process(false)
			game.campaign.starting = id
			game.selected_country = id
			game.start_round()
			for brain in game.brains: brain.legacy_tactics = old
			var survival: Array[float] = [120,120,120,120]
			var initial: float = 0
			for team in range(1,4): initial += game.territory.fractions[team]
			var active_before: Array[bool] = [true,true,true,true]
			var loop_samples: Array[float] = []
			game.territory.captured.connect(func(team: int,_gain: float,_point: Vector2) -> void:
				if team > 0: loop_samples.append(BotBrain.overlap_ratio(game.actors[team].trail.points)))
			for tick in 7200:
				if game.state != game.State.PLAYING: break
				# Fixed roster comparison isolates tactics; no reinforcement confound.
				game.arrival_elapsed = 0
				game._physics_process(1.0/60)
				for team in range(1,4):
					if active_before[team] and not game.actors[team].active:
						survival[team] = float(tick)/60
						active_before[team] = false
				if tick%600 == 0: await process_frame
			var final: float = 0
			var attacks: int = 0
			var fails: int = 0
			var abandoned: int = 0
			var idle: float = 0
			for team in range(1,4):
				final += game.territory.fractions[team]
				attacks += game.brains[team].completed_attacks
				fails += game.brains[team].failed_pursuits
				abandoned += game.brains[team].abandoned_loops
				idle += game.brains[team].idle_seconds
			var item := {"country":id,"old018":old,"winner":game.winning_team,"initial":initial,"final":final,"survival_seconds":survival,"recorded_attacks":attacks,"failed_pursuits":fails,"abandoned_loops":abandoned,"idle_seconds":idle}
			var overlap: float = 0
			for value in loop_samples: overlap += value
			item["completed_loop_mean_overlap"] = overlap/maxi(1,loop_samples.size())
			item["completed_captures"] = loop_samples.size()
			report.append(item)
			print("CONTEST ",JSON.stringify(item))
			game.queue_free()
			await process_frame
	var file := FileAccess.open("res://docs/contested-0.1.9.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("RESULT 4 matched contested simulations completed")
	quit()
