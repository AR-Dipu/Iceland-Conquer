extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func percentile(values: Array, ratio: float) -> float:
	values.sort()
	return values[mini(values.size()-1,int(values.size()*ratio))]
func run() -> void:
	var corpus: Array = []
	for country in ["bgd","ind","lka","jpn","isl"]:
		seed(190)
		var game = load("res://scenes/main.tscn").instantiate()
		game.profile_path = "user://capture_perf_"+Crypto.new().generate_random_bytes(8).hex_encode()
		root.add_child(game)
		await process_frame
		game.set_physics_process(false)
		game.selected_country = country
		game.campaign.starting = country
		game.difficulty = 2
		game.start_round()
		var before: Dictionary = {"regions":[]}
		game.territory.captured.connect(func(team: int,_gain: float,_at: Vector2) -> void:
			var path: PackedVector2Array = game.actors[team].trail.points.duplicate()
			if path.size() >= 2:
				corpus.append({"country":country,"team":team,"path":path,"regions":before.regions.duplicate(true),"outline":game.current_map.outline.duplicate(),"config":game.config})
		)
		for tick in 3600:
			if game.state != game.State.PLAYING: break
			before.regions = game.territory.regions.duplicate(true)
			game.arrival_elapsed = 0
			game._physics_process(1.0/60)
			if tick%600 == 0: await process_frame
		print("CORPUS ",country," ",corpus.size())
		game.queue_free()
		await process_frame
	var samples: Array = []
	var old_times: Array = []
	var new_times: Array = []
	for index in corpus.size():
		var item: Dictionary = corpus[index]
		var results: Array = []
		for baseline in ([true,false] if index%2 == 0 else [false,true]):
			var manager = load("res://tests/fixtures/territory_0111.gd").new() if baseline else TerritoryManager.new()
			manager.config = item.config
			manager.island = item.outline
			manager.island_area = IslandGeometry.area(item.outline)
			manager.regions = item.regions.duplicate(true)
			manager.fractions.resize(item.regions.size())
			manager.fractions.fill(0.0)
			manager._update_fractions()
			var began := Time.get_ticks_usec()
			var ok: bool = manager.capture(item.team,item.path,PackedVector2Array())
			var duration: int = Time.get_ticks_usec()-began
			var areas: Array = []
			for team in manager.regions:
				var area: float = 0
				for polygon in team: area += IslandGeometry.area(polygon)
				areas.append(area)
			results.append({"baseline":baseline,"ok":ok,"areas":areas,"us":duration})
			manager.free()
		assert(results[0].ok == results[1].ok,"Matched capture success differs")
		for team in results[0].areas.size(): assert(absf(results[0].areas[team]-results[1].areas[team]) < 2.0,"Matched capture area differs beyond boolean precision")
		if not results[0].ok: continue
		for result in results:
			if result.baseline: old_times.append(result.us)
			else: new_times.append(result.us)
		samples.append({"country":item.country,"measurements":results})
	var report := {"cases":samples.size(),"source":"Identical pre-capture ownership and paths sampled from seeded Hard matches on five countries; original complete capture manager/geometry/topology versus current; alternating measurement order; no render upload", "baseline_median_us":percentile(old_times,0.5),"baseline_p95_us":percentile(old_times,0.95),"after_median_us":percentile(new_times,0.5),"after_p95_us":percentile(new_times,0.95),"samples":samples}
	var file := FileAccess.open("res://docs/capture-performance-0.1.13.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	report.erase("samples")
	print("RESULT MATCHED CAPTURE ",JSON.stringify(report))
	quit()

