extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var report: Array = []
	var args := OS.get_cmdline_user_args()
	var frozen_rows: Array = []
	if FileAccess.file_exists("res://docs/contested-0.1.11-frozen-baseline.json"):
		frozen_rows = JSON.parse_string(FileAccess.get_file_as_string("res://docs/contested-0.1.11-frozen-baseline.json"))
	for match_seed in [190,7016,111]:
		if args.has("quick") and match_seed != 190: continue
		for country in ["bgd","ind","lka","jpn","isl"]:
			if args.has("quick") and country != "bgd": continue
			for baseline in [true,false]:
				var reused: bool = false
				if baseline:
					for row in frozen_rows:
						if int(row.seed) == match_seed and row.country == country:
							var copy: Dictionary = row.duplicate(true)
							copy["reused_frozen_measurement"] = true
							report.append(copy)
							print("CONTEST ",JSON.stringify(copy))
							reused = true
							break
				if reused: continue
				seed(match_seed)
				var game = load("res://scenes/main.tscn").instantiate()
				game.profile_path = "user://contest111_"+Crypto.new().generate_random_bytes(8).hex_encode()
				root.add_child(game)
				await process_frame
				game.set_physics_process(false)
				game.selected_country = country
				game.campaign.starting = country
				game.difficulty = 2
				game.start_round()
				game.territory.legacy_planning_budget = baseline
				for team in range(1,8):
					game.brains[team] = load("res://tests/fixtures/brain_0110.gd").new(match_seed+team) if baseline else BotBrain.new(match_seed+team)
					game.brains[team].reset()
				var initial: float = 0
				for team in range(1,8): initial += game.territory.fractions[team]
				var cuts: int = 0
				var reverse: float = 0
				var vulnerable_distance: float = 0
				var last_positions: Array[Vector2] = []
				for actor in game.actors: last_positions.append(actor.position)
				for tick in 7200:
					if game.state != game.State.PLAYING: break
					game.arrival_elapsed = 0
					var living: int = 0
					for actor in game.actors: living += int(actor.active)
					game._physics_process(1.0/60)
					for actor in game.actors: living -= int(actor.active)
					cuts += living
					for team in range(1,8):
						var actor: ConquerCharacter = game.actors[team]
						var brain = game.brains[team]
						var a: Vector2 = last_positions[team]
						var b: Vector2 = actor.position
						last_positions[team] = b
						if not actor.active or not brain.has_plan or brain.tactical_action != "expand" or actor.trail.points.size() < 2: continue
						var distance := a.distance_to(b)
						vulnerable_distance += distance
						for index in actor.trail.query_segments(a,b,10):
							var p: Vector2 = actor.trail.points[index]
							var q: Vector2 = actor.trail.points[index+1]
							if a.direction_to(b).dot(p.direction_to(q)) < -0.8 and IslandGeometry.segment_distance(a,b,p,q) < 10:
								reverse += distance
								break
					if tick%600 == 0: await process_frame
				var land: float = 0
				var surviving: int = 0
				var abandoned: int = 0
				var idle: float = 0
				for team in range(1,8):
					land += game.territory.fractions[team]
					surviving += int(game.actors[team].active)
					abandoned += game.brains[team].abandoned_loops
					idle += game.brains[team].idle_seconds
				var row := {"seed":match_seed,"country":country,"baseline":baseline,"initial":initial,"net_land":land-initial,"land":land,"surviving_bots":surviving,"cuts":cuts,"abandoned":abandoned,"scheduled_wait":idle,"normal_reverse_units":reverse,"normal_vulnerable_units":vulnerable_distance,"winner":game.winning_team}
				report.append(row)
				print("CONTEST ",JSON.stringify(row))
				game.queue_free()
				await process_frame
	var file := FileAccess.open("res://docs/contested-0.1.11"+("-quick" if args.has("quick") else "")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("RESULT ",report.size()," complete-AI matched simulations")
	quit()
