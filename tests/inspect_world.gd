extends SceneTree
func _initialize() -> void:
	var catalog := CountryCatalog.new()
	for id in ["chl","sdn"]:
		var country := catalog.find(id)
		country.build()
		print(id," simple=",IslandGeometry.simple(country.outline)," spawns=",country.spawn_points," valid=",country.valid())
		for attempt in 30:
			country._build_homes([4,6,8][attempt%3])
			if not country.valid():
				print("FAIL ",id," count=",country.spawn_points.size()," radius=",country.home_radius," points=",country.spawn_points)
				for team in country.spawn_points.size():
					print(team," regions=",country.initial_territories[team].size()," owned=",IslandGeometry.contains(_typed(country.initial_territories[team]),country.spawn_points[team])," clearance=",country.spawn_points[team].distance_to(IslandGeometry.nearest(country.outline,country.spawn_points[team]).point))
	quit()
func _typed(polys: Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for p in polys: result.append(p)
	return result
