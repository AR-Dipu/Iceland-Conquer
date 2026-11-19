extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = "user://corner_test_"+Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	var checks: int = 0
	for id in ["bgd","ind","lka","jpn","isl"]:
		for level in 3:
			game.campaign.starting = id
			game.selected_country = id
			game.difficulty = level
			game.choose_country()
			game.start_round()
			for actor in game.actors.slice(1):
				var vertex: Vector2 = game.island[(actor.team*17)%game.island.size()]
				var spawn: Vector2 = game.current_map.center
				for step in range(1,21):
					var candidate: Vector2 = vertex.lerp(game.current_map.center,float(step)/20)
					if Geometry2D.is_point_in_polygon(candidate,game.island):
						spawn = candidate
						break
				actor.position = spawn
				actor.previous = spawn
				actor.velocity = Vector2.ZERO
				game.brains[actor.team].wait = 0
				var travel: float = 0
				for tick in 360:
					var direction: Vector2 = game.brains[actor.team].steer(actor,game.territory,game.current_map,1.0/60)
					actor.advance(direction,1.0/60,game.island)
					travel += actor.previous.distance_to(actor.position)
					assert(Geometry2D.is_point_in_polygon(actor.position,game.island),"Opponent left island")
				if travel <= 25:
					print("STUCK ",id," level=",level," team=",actor.team," from=",spawn," to=",actor.position," velocity=",actor.velocity," waypoints=",game.brains[actor.team].waypoints)
					print("SAFE=",game.current_map._safe_spawn(spawn)," nearest=",IslandGeometry.nearest(game.island,spawn)," clockwise=",Geometry2D.is_polygon_clockwise(game.island))
					for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]: print("MOTION ",direction," ",ShoreMotion.solve(spawn,direction*91,0.35,game.island))
					quit(1)
					return
				checks += 1
		print("CORNER PASS ",id)
	game.queue_free()
	await process_frame
	print("RESULT ",checks," opponent corner scenarios passed")
	quit()
