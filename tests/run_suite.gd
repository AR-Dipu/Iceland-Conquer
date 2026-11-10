extends SceneTree
var checks: int = 0
var failures: int = 0
var captures: int = 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var square := PackedVector2Array([Vector2.ZERO, Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)])
	var hole := PackedVector2Array([Vector2(30, 30), Vector2(70, 30), Vector2(70, 70), Vector2(30, 70)])
	var pieces: Array[PackedVector2Array] = IslandGeometry.subtract(square, hole)
	var total: float = 0
	for p in pieces:
		total += IslandGeometry.area(p)
	check(absf(total - 8400) < 0.1 and not IslandGeometry.contains(pieces, Vector2(50, 50)), "Hole subtraction preserves empty space and exact area")
	var path := PackedVector2Array([Vector2(95, 30), Vector2(140, 30), Vector2(140, 75), Vector2(95, 75)])
	check(absf(IslandGeometry.area(IslandGeometry.boundary_capture(square, path)) - 1800) < 1, "Boundary capture chooses smaller valid enclosure")
	check(IslandGeometry.boundary_capture(square, PackedVector2Array([Vector2.ZERO])).is_empty(), "Degenerate loops are rejected")
	var rounded: PackedVector2Array = IslandGeometry.soften(square)
	check(IslandGeometry.simple(rounded) and rounded.size() > square.size(), "Capture corners become smooth valid polygon arcs")
	check(IslandGeometry.segment_distance(Vector2.ZERO, Vector2(10, 10), Vector2(0, 10), Vector2(10, 0)) == 0, "Swept trail crossing cannot tunnel between samples")

	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	check(game.state == game.State.SELECTION and game.actors.is_empty() and not game.hud.mobile.enabled, "Startup shows selection with no active gameplay")
	check(game.selected_country == "bgd" and game.selector.visible and not game.hud.visible, "Bangladesh is initially selected with Play visible")
	for tick in 120:
		game._physics_process(1.0 / 60.0)
	check(game.actors.is_empty() and game.state == game.State.SELECTION, "Idle selection never starts bots or scoring")
	check(game.catalog.maps.size() == 5, "Five offline countries are available")
	for map in game.catalog.maps:
		check(map.valid() and absf(maxf(map.land_bounds.size.x, map.land_bounds.size.y) - 2400) < 0.2, map.display_name + " has valid country geometry and 2400-unit extent")
		var exclusive: bool = true
		for i in 3:
			for j in range(i + 1, 3):
				for a in map.initial_territories[i]:
					for b in map.initial_territories[j]:
						for intersection in Geometry2D.intersect_polygons(a, b):
							exclusive = exclusive and IslandGeometry.area(intersection) < 0.1
		check(exclusive, map.display_name + " starts with separate owned home patches")
		var route: PackedVector2Array = map.route(map.spawn_points[0], map.spawn_points[1])
		var inside: bool = not route.is_empty()
		var anchor: Vector2 = map.spawn_points[0]
		for p in route:
			inside = inside and IslandGeometry.segment_inside(map.outline, anchor, p)
			anchor = p
		check(inside and anchor.distance_to(map.spawn_points[1]) < 1, map.display_name + " has a land-only navigation route between spawns")
	check(game.catalog.find("jpn").decorative_islands.size() == 3, "Japan uses Honshu and three offshore scenery outlines")
	game.selector.select("jpn")
	check(game.selected_country == "jpn" and game.actors.is_empty(), "Selecting Japan updates choice without starting gameplay")
	game.selector.play_button.pressed.emit()
	check(game.running and game.actors.size() == 3 and game.current_map.country_id == "jpn", "Play loads selected country and starts all characters")
	check(not game.hud.mobile.has_target and game.hud.mobile.pointer == MobileInput.NONE, "Play does not leak a movement gesture")
	check(game.config.team_colors[0].is_equal_approx(Color("9b5cff")), "Player territory and trails use requested purple")
	check(game.actors[0].sprite.texture.resource_path.ends_with("purple_player.png"), "Purple player uses the new crowned sprite")
	check(game.config.max_trail_points == 1024, "Large-map trail memory is capped at 1024 samples")
	var previous_world: WeakRef = weakref(game.world_root)
	for map in game.catalog.maps:
		game.choose_country()
		game.selector.select(map.country_id)
		game.start_round()
		check(game.current_map == map and game.actors[0].position == map.spawn_points[0] and game.home_regions[0].size() > 2, map.display_name + " loads its own spawns and territory")
	check(previous_world.get_ref() == null, "Switching countries frees the previous world and actors")
	check(game.get_children().size() == 3, "Repeated switching leaves one world and two canvas layers")
	game.choose_country()
	game.selector.select("bgd")
	game.start_round()
	for brain in game.brains:
		brain.wait = 1000
	var actor: ConquerCharacter = game.actors[0]
	var mobile: MobileInput = game.hud.mobile
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = root.canvas_transform * (actor.position + Vector2(70, 0))
	mobile._unhandled_input(touch)
	check(mobile.has_target and mobile.movement(actor.position, game.island).x > 0.9, "Holding the screen steers toward a world-space target")
	var other := InputEventScreenTouch.new()
	other.index = 1
	other.pressed = true
	other.position = touch.position + Vector2(0, 70)
	mobile._unhandled_input(other)
	check(mobile.pointer == 0, "Secondary movement finger cannot steal control")
	other.pressed = false
	mobile._input(other)
	check(mobile.pointer == 0, "Secondary release cannot stop the active finger")
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = root.canvas_transform * (actor.position + Vector2(0, 90))
	mobile._input(drag)
	check(mobile.movement(actor.position, game.island).y > 0.9, "Dragging changes steering without a joystick")
	actor.velocity = Vector2(80, 0)
	touch.pressed = false
	mobile._input(touch)
	check(not mobile.has_target and actor.velocity == Vector2.ZERO, "Releasing immediately stops velocity and clears the target")
	var initial: Vector2 = actor.position
	mobile.has_target = true
	mobile.target_world = initial + Vector2(30, 0)
	for tick in 100:
		game._physics_process(1.0 / 60.0)
	check(actor.position.distance_to(mobile.target_world) <= 7.1 and actor.velocity == Vector2.ZERO, "Reaching held target stops without orbiting or jitter")
	mobile.release()
	var ui_transform: Transform2D = game.ui_root.get_global_transform()
	game.camera.position += Vector2(180, 100)
	game.camera.reset_smoothing()
	game.camera.force_update_scroll()
	var screen_point := Vector2(240, 650)
	check(mobile.screen_to_world(screen_point).distance_to(root.canvas_transform.affine_inverse() * screen_point) < 0.001, "Touch conversion follows the actual camera canvas transform")
	check(game.ui_root.get_global_transform().is_equal_approx(ui_transform), "Camera movement leaves HUD fixed on screen")
	var mini: Transform2D = game.hud.minimap_transform()
	check(Rect2(539, 213, 140, 164).grow(1).has_point(mini * actor.position), "Minimap places player inside the country preview")
	var shore: Vector2 = IslandGeometry.clamp_inside(game.island, Vector2(-9000, -9000))
	check(Geometry2D.is_point_in_polygon(shore, game.island), "Off-island touch targets clamp to valid shoreline")
	# Exercise actual GUI event dispatch: touching Pause must never acquire movement.
	var pause_point: Vector2 = game.hud.pause_button.get_global_transform_with_canvas() * (game.hud.pause_button.size * 0.5)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = pause_point
	root.push_input(click, true)
	var click_up: InputEventMouseButton = click.duplicate()
	click_up.pressed = false
	root.push_input(click_up, true)
	check(game.state == game.State.PAUSED and not mobile.has_target and not mobile.enabled, "GUI pause button consumes its gesture before movement input")
	game.resume_round()
	check(game.running and mobile.enabled and not mobile.has_target, "Resume enables clean movement input")
	var key := InputEventKey.new()
	key.keycode = KEY_D
	key.physical_keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	check(mobile.movement(actor.position, game.island).x == 1, "WASD remains available")
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	check(mobile.movement(actor.position, game.island) == Vector2.ZERO, "Keyboard release clears movement")
	game.choose_country()
	game.selector.select("lka")
	game.start_round()
	actor = game.actors[0]
	actor.protection = 1000
	var before: float = game.territory.fractions[0]
	var origin: Vector2 = actor.position
	var radius: float = game.current_map.home_radius * 1.1
	var capture_path: Array[Vector2] = []
	for angle_index in 32:
		var outward := Vector2.from_angle(TAU * angle_index / 32.0)
		var side := outward.orthogonal()
		var a: Vector2 = origin + outward * radius * 1.5 + side * radius * 0.45
		var b: Vector2 = origin + outward * radius * 1.5 - side * radius * 0.45
		if IslandGeometry.segment_inside(game.island, origin, a) and IslandGeometry.segment_inside(game.island, a, b) and IslandGeometry.segment_inside(game.island, b, origin) and not game.territory.owned(0, a):
			capture_path = [a, b, origin]
			break
	for waypoint in capture_path:
		var iterations: int = 0
		while actor.position.distance_to(waypoint) > 4 and iterations < 1600:
			actor.advance(actor.position.direction_to(waypoint), 1.0 / 60.0, game.island)
			game._update_trail(actor)
			iterations += 1
	check(not capture_path.is_empty() and game.territory.fractions[0] > before + 0.001, "Real movement out and home captures country territory")
	check(actor.trail.points.is_empty(), "Closing a loop removes its exposed trail")
	var all_area: float = 0
	for fraction in game.territory.fractions:
		all_area += fraction
	check(all_area <= 1.001, "Capture preserves nonoverlapping island area accounting")
	# A rival's cut resets that rival only.
	var center: Vector2 = game.current_map.center
	for character in game.actors:
		character.previous = character.position
		character.trail.clear()
	game.actors[1].protection = 0
	game.actors[1].trail.points = PackedVector2Array([center - Vector2(35, 0), center + Vector2(35, 0)])
	actor.previous = center - Vector2(0, 20)
	actor.position = center + Vector2(0, 20)
	game._resolve_attacks()
	check(game.running and game.actors[1].trail.points.is_empty() and game.actors[1].protection > 0, "Cutting a bot tail resets only the bot")
	actor.protection = 0
	actor.trail.points = PackedVector2Array([center - Vector2(35, 0), center + Vector2(35, 0)])
	actor.previous = actor.position
	game.actors[1].previous = center - Vector2(0, 20)
	game.actors[1].position = center + Vector2(0, 20)
	game._resolve_attacks()
	check(game.state == game.State.SELECTION and game.selector.message == "Your tail was cut!" and game.selected_country == "lka", "Player tail cut returns to Play with the same country selected")
	check(not mobile.has_target and not game.hud.mobile.enabled and game.actors.all(func(a: ConquerCharacter) -> bool: return a.trail.points.is_empty() and a.velocity == Vector2.ZERO), "Tail-cut transition clears all trails and movement")
	game.start_round()
	actor = game.actors[0]
	check(actor.position == game.current_map.spawn_points[0] and absf(game.territory.fractions[0] - before) < 0.001, "Play after defeat creates fresh territory and spawns")
	var anchor: Vector2 = game.actors[2].position - Vector2(35, 0)
	actor.protection = 0
	actor.trail.points = PackedVector2Array([anchor, anchor + Vector2(60, 0), anchor + Vector2(60, -20), anchor + Vector2(80, -20), anchor + Vector2(80, 20), anchor + Vector2(30, 20), anchor + Vector2(30, -30), anchor + Vector2(50, -30)])
	actor.previous = anchor + Vector2(20, -10)
	actor.position = anchor + Vector2(20, 10)
	game._resolve_attacks()
	check(game.state == game.State.SELECTION, "Player self-crossing also returns to the Play screen")
	game.start_round()
	game.territory.fractions[0] = 0.61
	game._captured(0, 0.1, game.actors[0].position)
	check(game.state == game.State.ROUND_OVER and game.hud.winner == 0 and not game.hud.mobile.enabled, "60 percent shows player victory and disables movement")
	game.start_round()
	game.territory.fractions[2] = 0.61
	game._captured(2, 0.1, game.actors[2].position)
	check(game.state == game.State.ROUND_OVER and game.hud.winner == 2, "Rivals can win the selected country")
	game.choose_country()
	game.selector.select("bgd")
	game.start_round()
	game.territory.captured.connect(func(_team: int, _gain: float, _at: Vector2) -> void: captures += 1)
	game.actors[0].protection = 1000
	var valid: bool = true
	var started: int = Time.get_ticks_msec()
	for tick in 7200:
		game._physics_process(1.0 / 60.0)
		if not game.running:
			break
		if tick % 120 == 0:
			var sum: float = 0
			for fraction in game.territory.fractions:
				valid = valid and is_finite(fraction) and fraction >= 0
				sum += fraction
			valid = valid and sum <= 1.002
			for character in game.actors:
				valid = valid and Geometry2D.is_point_in_polygon(character.position, game.island) and character.trail.points.size() <= 1024
	check(valid and game.running, "Two-minute country simulation preserves shoreline, ownership and bounded trails")
	check(captures > 0, "Bots capture territory on the larger country map")
	print("SIMULATION: 7200 ticks, ", captures, " captures, ", Time.get_ticks_msec() - started, " ms")
	for country_id in ["ind", "lka", "jpn", "isl"]:
		game.choose_country()
		game.selector.select(country_id)
		game.start_round()
		game.actors[0].protection = 1000
		var country_captures: Array[int] = [0]
		game.territory.captured.connect(func(_team: int, _gain: float, _at: Vector2) -> void: country_captures[0] += 1)
		var country_valid: bool = true
		for tick in 3600:
			game._physics_process(1.0 / 60.0)
			if not game.running:
				break
			if tick % 120 == 0:
				var ownership: float = 0
				for fraction in game.territory.fractions:
					ownership += fraction
				for character in game.actors:
					country_valid = country_valid and Geometry2D.is_point_in_polygon(character.position, game.island)
				country_valid = country_valid and ownership <= 1.002
		check(country_valid and country_captures[0] > 0, country_id + " one-minute bot simulation captures land without leaving the country")
	var source_maps: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/countries.json"))
	var japan_data: Dictionary = source_maps.filter(func(m: Dictionary) -> bool: return m.id == "jpn")[0]
	check(japan_data.mainland_name == "Honshu" and japan_data.mainland_latitude_min > 33, "Japan source geometry excludes Kyushu from playable Honshu")
	var icon: Image = load("res://assets/icons/launcher.png").get_image()
	var foreground: Image = load("res://assets/icons/foreground.png").get_image()
	check(icon.get_size() == Vector2i(1024, 1024) and foreground.get_size() == Vector2i(1024, 1024), "Standard and adaptive foreground assets are 1024 square")
	var used := Rect2i(512, 512, 0, 0)
	for y in foreground.get_height():
		for x in foreground.get_width():
			# Ignore sub-percent alpha ringing from size conversion; verify visible art.
			if foreground.get_pixel(x, y).a >= 0.01:
				used = used.expand(Vector2i(x, y))
	check(used.position.x >= 165 and used.position.y >= 165 and used.end.x <= 859 and used.end.y <= 859, "Adaptive mascot fits inside the central safe region")
	game.queue_free()
	await process_frame
	print("RESULT: ", checks - failures, "/", checks, " checks passed")
	quit(0 if failures == 0 else 1)
