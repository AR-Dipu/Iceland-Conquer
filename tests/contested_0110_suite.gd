extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	# Compare the previous committed planner against the new one with identical
	# movement, capture rules, tactical decisions, seed and spawn arrangement.
	var output: Array = []
	assert(OS.execute("git",PackedStringArray(["-c","safe.directory=D:/irinfo/App","show","a691774:scripts/bot_brain.gd"]),output) == 0)
	var source: String = output[0]
	var begin: int = source.find("func _plan(")
	var end: int = source.find("\nfunc _reposition",begin)
	var old_script := GDScript.new()
	old_script.source_code = "extends BotBrain\n"+source.substr(begin,end-begin)
	assert(old_script.reload() == OK)
	var report: Array = []
	for id in ["bgd","isl"]:
		if OS.get_cmdline_user_args().has("bgd") and id != "bgd": continue
		for old in [true,false]:
			if old and OS.get_cmdline_user_args().has("current-only"): continue
			seed(190)
			var game = load("res://scenes/main.tscn").instantiate()
			game.profile_path = "user://contest110_"+Crypto.new().generate_random_bytes(8).hex_encode()
			root.add_child(game)
			await process_frame
			game.set_physics_process(false)
			game.selected_country = id
			game.campaign.starting = id
			game.difficulty = 2
			game.start_round()
			for team in range(1,8):
				game.brains[team] = old_script.new(190+team) if old else BotBrain.new(190+team)
				game.brains[team].reset()
			var cuts: Array[int] = [0]
			var overlaps: Array[float] = []
			game.territory.captured.connect(func(team: int,_gain: float,_point: Vector2) -> void:
				if team > 0: overlaps.append(BotBrain.overlap_ratio(game.actors[team].trail.points)))
			for tick in 7200:
				if game.state != game.State.PLAYING: break
				game.arrival_elapsed = 0
				var living: int = 0
				for actor in game.actors: living += int(actor.active)
				game._physics_process(1.0/60)
				for actor in game.actors: living -= int(actor.active)
				cuts[0] += living
				if tick%600 == 0: await process_frame
			var land: float = 0
			var survived: int = 0
			var abandoned: int = 0
			var idle: float = 0
			for team in range(1,8):
				land += game.territory.fractions[team]
				survived += int(game.actors[team].active)
				abandoned += game.brains[team].abandoned_loops
				idle += game.brains[team].idle_seconds
			var overlap: float = 0
			for value in overlaps: overlap += value
			var row := {"country":id,"previous_planner":old,"land":land,"surviving_bots":survived,"cuts":cuts[0],"abandoned":abandoned,"idle_seconds":idle,"winner":game.winning_team,"captures":overlaps.size(),"route_overlap":overlap/maxi(1,overlaps.size())}
			report.append(row)
			print("CONTEST ",JSON.stringify(row))
			game.queue_free()
			await process_frame
	var file := FileAccess.open("res://docs/contested-0.1.10.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("RESULT ",report.size()," matched Hard contested simulations completed")
	quit()
