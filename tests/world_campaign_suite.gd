extends SceneTree
var checks: int = 0
func verify(value: bool, label: String) -> void:
	if not value:
		push_error(label)
		quit(1)
		assert(value,label)
	checks += 1
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var catalog := CountryCatalog.new()
	verify(catalog.maps.size() == 176,"Full roster")
	verify(catalog.maps.all(func(c: CountryMap) -> bool: return not c.built),"Lazy loading")
	var seen: Dictionary = {}
	var pending: Array[String] = [catalog.maps[0].country_id]
	while not pending.is_empty():
		var id: String = pending.pop_back()
		if seen.has(id): continue
		seen[id] = true
		for neighbor in catalog.find(id).neighbors:
			verify(catalog.find(neighbor).neighbors.has(id),"Symmetric connections")
			pending.append(neighbor)
	verify(seen.size() == catalog.maps.size(),"Entire campaign reachable")
	for country in ([] if OS.get_cmdline_user_args().has("--quick") else catalog.maps):
		verify(country.valid(),country.display_name+" valid geometry")
		for total in [4,6,8]:
			country._build_homes(total)
			verify(country.spawn_points.size() == total and country.valid(),country.display_name+" valid roster")
			for team in total:
				verify(IslandGeometry.contains(_typed(country.initial_territories[team]),country.spawn_points[team]),"Spawn owned")
				var size: float = 0
				for p in country.initial_territories[team]: size += IslandGeometry.area(p)
				verify(size > 1 and size < PI*50*50,"Dot starting patch")
				for other in range(team+1,total):
					for a in country.initial_territories[team]:
						for b in country.initial_territories[other]:
							var overlap: float = 0
							for piece in Geometry2D.intersect_polygons(a,b): overlap += IslandGeometry.area(piece)
							verify(overlap < 0.1,"Exclusive starting ownership")
		print("MAP PASS ",country.display_name)
	var progress := CampaignProgress.new()
	progress.path = "user://campaign_test_"+Crypto.new().generate_random_bytes(8).hex_encode()+".cfg"
	verify(progress.can_attack("bgd",catalog) and progress.can_attack("isl",catalog),"Any first country")
	verify(progress.begin("bgd") and not progress.can_attack("isl",catalog),"First target locks")
	verify(progress.conquer("bgd") and progress.can_attack("ind",catalog),"Adjacent country unlocked")
	verify(not progress.can_attack("bgd",catalog),"Conquered target locked")
	verify(progress.set_name("  Luna  ") and progress.player_name == "Luna","Editable name")
	var first := progress.round_names(8)
	var second := progress.round_names(8)
	var unique := {}
	for name in second: unique[name.to_lower()] = true
	verify(unique.size() == 8,"Distinct names")
	for name in second.slice(1): verify(not first.has(name),"Fresh names on replay")
	var loaded := CampaignProgress.new()
	loaded.path = progress.path
	loaded.open(PracticeWallet.new())
	verify(loaded.player_name == "Luna" and loaded.conquered.has("bgd"),"Campaign persists")
	DirAccess.remove_absolute(progress.path)
	var bowtie := PackedVector2Array([Vector2(0,0),Vector2(100,100),Vector2(0,100),Vector2(100,0)])
	var faces := IslandGeometry.split_faces(bowtie)
	verify(faces.size() == 2 and is_equal_approx(IslandGeometry.face_area(bowtie),5000),"Self-crossing faces preserved")
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = "user://world_test_"+Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.selected_country = "bgd"
	game.start_round()
	verify(game.running,"Country launches")
	var actor: ConquerCharacter = game.actors[0]
	actor.protection = 0
	actor.trail.points = bowtie
	actor.previous = Vector2(-10,50)
	actor.position = Vector2(110,50)
	game._resolve_attacks()
	verify(game.running,"Self-crossing is safe")
	game.territory.fractions[1] = 0.99
	game._captured(1,0.1,Vector2.ZERO)
	verify(game.winning_team == 1 and game.hud.display_percent(1) == 100,"Named opponent wins at 99 percent")
	verify(not game.campaign.conquered.has("bgd"),"Opponent grants no conquest")
	game.start_round()
	game.territory.fractions[0] = 0.9899
	game._captured(0,0.1,Vector2.ZERO)
	verify(game.running and game.hud.display_percent(0) == 98,"Below threshold remains playing")
	game.territory.fractions[0] = 0.99
	game._captured(0,0.1,Vector2.ZERO)
	verify(game.winning_team == 0 and game.hud.display_percent(0) == 100 and game.campaign.conquered.has("bgd"),"Player victory grants conquest at 99")
	game.start_round()
	verify(game.running,"Free replay allowed after winning")
	game.queue_free()
	await process_frame
	print("RESULT ",checks," world campaign checks passed")
	quit()
func _typed(polys: Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for p in polys: result.append(p)
	return result
