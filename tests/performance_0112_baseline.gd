extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	seed(190)
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = "user://perf111_"+Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.selected_country = "bgd"
	game.campaign.starting = "bgd"
	game.difficulty = 2
	game.start_round()
	WorkMetrics.enabled = true
	WorkMetrics.samples.clear()
	var samples: Array[float] = []
	var mesh_us: int = 0
	for tick in 3600:
		game.arrival_elapsed = 0
		var began := Time.get_ticks_usec()
		game._physics_process(1.0/60)
		var mesh_start := Time.get_ticks_usec()
		game.territory.mesh_snapshot()
		mesh_us += Time.get_ticks_usec()-mesh_start
		samples.append(float(Time.get_ticks_usec()-began)/1000)
		if tick%600 == 0: await process_frame
	samples.sort()
	var report := {"frames":samples.size(),"median_cpu_ms":samples[1800],"p95_cpu_ms":samples[3420],"worst_cpu_ms":samples[-1],"mesh_total_ms":mesh_us/1000.0,"ownership":game.territory.fractions,"phases":WorkMetrics.report()}
	print("PERFORMANCE ",JSON.stringify(report))
	var file := FileAccess.open("res://docs/performance-0.1.12-baseline.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	WorkMetrics.enabled = false
	quit()
