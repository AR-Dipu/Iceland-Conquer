extends Node2D
## Explicit session states keep input, AI and loading transitions independent.
enum State { SELECTION, LOADING, PLAYING, PAUSED, ROUND_OVER, DEFEATED, DEMO_AD }
const CHARACTER_SCENE: PackedScene = preload("res://scenes/character.tscn")
var config: GameConfig = preload("res://resources/default_config.tres").duplicate(true)
var state: State = State.SELECTION
var running: bool:
	get:
		return state == State.PLAYING
var difficulty: int = 0
var selected_country: String = "bgd"
var catalog: CountryCatalog
var current_map: CountryMap
var world_root: Node2D
var world: IslandWorld
var territory: TerritoryManager
var camera: Camera2D
var hud: GameHUD
var selector: CountrySelector
var ui_root: Control
var actors: Array[ConquerCharacter] = []
var brains: Array[BotBrain] = []
var home_points: Array[Vector2] = []
var home_regions: Array[PackedVector2Array] = []
var island := PackedVector2Array()
var winning_team: int = -1
var feedback: Node2D
var popups: Array[Dictionary] = []
var frame: int = 0
var preview_path: String = ""
var reward: DemoRewardService
var reward_token: int = -1

func _ready() -> void:
	get_tree().quit_on_go_back = false
	reward = DemoRewardService.new()
	add_child(reward)
	reward.completed.connect(_reward_completed)
	reward.progress.connect(func(left: float) -> void: hud.demo_remaining = left; hud.queue_redraw())
	catalog = CountryCatalog.new()
	var ocean_layer := CanvasLayer.new()
	ocean_layer.layer = -100
	add_child(ocean_layer)
	ocean_layer.add_child(TropicalOcean.new())
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 100
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.size = Vector2(720, 1280)
	ui_layer.add_child(ui_root)
	hud = GameHUD.new()
	ui_root.add_child(hud)
	hud.setup(config)
	hud.mobile.movement_released.connect(_stop_player)
	hud.pause_requested.connect(pause_round)
	hud.resume_requested.connect(resume_round)
	hud.restart_requested.connect(start_round)
	hud.choose_country_requested.connect(choose_country)
	hud.revive_requested.connect(begin_revive)
	hud.cancel_ad_requested.connect(cancel_revive)
	selector = CountrySelector.new()
	ui_root.add_child(selector)
	selector.setup(catalog, hud.font)
	selector.country_selected.connect(_country_selected)
	selector.play_requested.connect(start_round)
	selector.difficulty_changed.connect(func(value: int) -> void: difficulty = value; hud.difficulty_name = ["EASY","MEDIUM","HARD"][value])
	get_viewport().size_changed.connect(_layout)
	_layout()
	_set_state(State.SELECTION)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-preview="):
			preview_path = arg.trim_prefix("--capture-preview=")

func _layout() -> void:
	if not is_instance_valid(ui_root):
		return
	var viewport_size := get_viewport_rect().size
	var top: float = 0
	var bottom: float = 0
	if OS.get_name() == "Android":
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var screen: Vector2i = DisplayServer.screen_get_size()
		if safe.size.y > 0 and screen.y > 0:
			var ratio: float = viewport_size.y / float(screen.y)
			top = safe.position.y * ratio
			bottom = (screen.y - safe.end.y) * ratio
	var available := Vector2(viewport_size.x, viewport_size.y - top - bottom)
	var fit: float = minf(available.x / 720.0, available.y / 1280.0)
	ui_root.scale = Vector2.ONE * fit
	ui_root.position = Vector2((viewport_size.x - 720 * fit) * 0.5, top + (available.y - 1280 * fit) * 0.5)

func _country_selected(country_id: String) -> void:
	if state == State.SELECTION and catalog.find(country_id) != null:
		selected_country = country_id

func _set_state(next: State) -> void:
	state = next
	var labels: Array[String] = ["selection", "loading", "playing", "paused", "round_over", "defeated", "demo_ad"]
	hud.set_mode(labels[state], winning_team)
	selector.visible = state == State.SELECTION or state == State.LOADING
	selector.play_button.disabled = state == State.LOADING
	if is_instance_valid(world_root):
		world_root.visible = state != State.SELECTION and state != State.LOADING
		world_root.process_mode = Node.PROCESS_MODE_INHERIT if state == State.PLAYING else Node.PROCESS_MODE_DISABLED
	for actor in actors:
		actor.velocity = Vector2.ZERO
		actor.previous = actor.position

func _clear_world() -> void:
	hud.mobile.release()
	hud.actors = []
	actors.clear()
	brains.clear()
	home_points.clear()
	home_regions.clear()
	popups.clear()
	if is_instance_valid(world_root):
		remove_child(world_root)
		world_root.free()
	world_root = null
	territory = null
	camera = null
	feedback = null

func load_country(country_id: String) -> bool:
	var choice: CountryMap = catalog.find(country_id)
	if choice == null or not choice.valid():
		return false
	_set_state(State.LOADING)
	_clear_world()
	current_map = choice
	selected_country = country_id
	island = current_map.outline
	current_map._build_homes([4,6,8][difficulty])
	config.spawn_points = current_map.spawn_points.duplicate()
	var palette: Array[int] = [1,2,3,4,5,6,7]
	palette.shuffle()
	config.cat_indices = [0]
	config.cat_indices.append_array(palette)
	var colors: Array[Color] = [Color("9b5cff"),Color("ff5b68"),Color("ffd33d"),Color("59d68b"),Color("23cde3"),Color("ff993f"),Color("f777c5"),Color("4388f4")]
	config.team_colors.clear()
	for index in config.cat_indices:
		config.team_colors.append(colors[index])
	world_root = Node2D.new()
	world_root.name = "CountryWorld"
	add_child(world_root)
	world = IslandWorld.new()
	world_root.add_child(world)
	world.setup(current_map)
	territory = TerritoryManager.new()
	world_root.add_child(territory)
	territory.setup(config, current_map)
	territory.territory_changed.connect(hud.update_scores)
	territory.captured.connect(_captured)
	for team in config.spawn_points.size():
		var actor: ConquerCharacter = CHARACTER_SCENE.instantiate()
		actor.setup(team, config)
		world_root.add_child(actor.trail)
		world_root.add_child(actor)
		actor.reset_actor()
		actors.append(actor)
		var brain := BotBrain.new(481 + team * 79 + country_id.hash())
		brain.reset()
		brains.append(brain)
		home_points.append(actor.position)
		home_regions.append(territory.region_at(team, actor.position))
	camera = Camera2D.new()
	camera.name = "FollowCamera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.zoom = Vector2.ONE * 0.9
	camera.limit_left = floori(current_map.camera_bounds.position.x)
	camera.limit_top = floori(current_map.camera_bounds.position.y)
	camera.limit_right = ceili(current_map.camera_bounds.end.x)
	camera.limit_bottom = ceili(current_map.camera_bounds.end.y)
	camera.position = actors[0].position + Vector2(0, -90)
	world_root.add_child(camera)
	camera.reset_smoothing()
	camera.force_update_scroll()
	feedback = Node2D.new()
	feedback.z_index = 50
	feedback.draw.connect(_draw_feedback)
	world_root.add_child(feedback)
	hud.bind_world(current_map, territory, actors, camera)
	return true

func start_round() -> void:
	if state == State.LOADING:
		return
	reward.cancel()
	reward_token = -1
	winning_team = -1
	if not load_country(selected_country):
		selector.message = "This island could not load. Choose another."
		_set_state(State.SELECTION)
		return
	selector.message = ""
	hud.toast_life = 0
	_set_state(State.PLAYING)

func choose_country(reason: String = "") -> void:
	reward.cancel()
	reward_token = -1
	for actor in actors:
		actor.velocity = Vector2.ZERO
		actor.previous = actor.position
		actor.trail.clear()
	popups.clear()
	winning_team = -1
	selector.message = reason
	selector.select(selected_country)
	_set_state(State.SELECTION)
	if is_instance_valid(camera):
		camera.enabled = false
	get_viewport().canvas_transform = Transform2D.IDENTITY

func _stop_player() -> void:
	if not actors.is_empty():
		actors[0].velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	frame += 1
	if not preview_path.is_empty() and frame == 12:
		_capture_preview.call_deferred()
	if state != State.PLAYING:
		return
	for actor in actors:
		if not actor.active:
			continue
		if actor.trail.points.is_empty() and territory.owned(actor.team, actor.position):
			home_points[actor.team] = actor.position
			home_regions[actor.team] = territory.region_at(actor.team, actor.position)
		var direction: Vector2
		if actor.team == 0:
			direction = hud.mobile.movement(actor.position, island)
			if direction == Vector2.ZERO:
				actor.velocity = Vector2.ZERO
		else:
			direction = brains[actor.team].steer(actor, territory, current_map, delta)
		actor.advance(direction, delta, island)
	_resolve_attacks()
	if state != State.PLAYING:
		return
	for actor in actors:
		if not actor.active:
			continue
		_update_trail(actor)
		if state != State.PLAYING:
			return
	camera.position = actors[0].position + Vector2(0, -90)

func _resolve_attacks() -> void:
	var defeated: Array[int] = []
	var killers: Dictionary = {}
	for attacker in actors:
		if not attacker.active:
			continue
		if attacker.previous.distance_squared_to(attacker.position) < 0.001:
			continue
		for victim in actors:
			if not victim.active or victim.protection > 0 or victim.trail.points.size() < 2:
				continue
			if attacker == victim:
				if not territory.owned(victim.team, victim.position) and victim.trail.hits(attacker.previous, attacker.position, 5.0, 5):
					if not defeated.has(victim.team):
						defeated.append(victim.team)
			elif victim.trail.hits(attacker.previous, attacker.position, config.trail_hit_radius):
				if not defeated.has(victim.team):
					defeated.append(victim.team)
					killers[victim.team] = attacker.team
	defeated.sort()
	for team in defeated:
		if team > 0:
			eliminate_bot(team, int(killers.get(team, -1)))
	if defeated.has(0):
		actors[0].trail.clear()
		_set_state(State.DEFEATED)
		return


func _update_trail(actor: ConquerCharacter) -> void:
	var trail: ConquerTrail = actor.trail
	if territory.owned(actor.team, actor.position):
		if trail.points.size() > 2:
			trail.append_point(actor.position)
			territory.capture(actor.team, trail.points, trail.departure)
			trail.clear()
		elif not trail.points.is_empty():
			trail.clear()
		home_points[actor.team] = actor.position
		home_regions[actor.team] = territory.region_at(actor.team, actor.position)
	else:
		if trail.points.is_empty():
			trail.departure = home_regions[actor.team].duplicate()
			if trail.departure.is_empty():
				reset_character(actor.team)
				return
			trail.append_point(home_points[actor.team])
		if trail.points[-1].distance_to(actor.position) >= config.trail_spacing:
			trail.append_point(actor.position)
		if trail.points.size() >= config.max_trail_points:
			reset_character(actor.team)
			if actor.team == 0:
				hud.show_toast("Trail too long. Try a smaller loop!")

func reset_character(team: int) -> void:
	if not actors[team].active:
		return
	if team == 0:
		hud.mobile.release()
	territory.reset_team(team)
	actors[team].reset_actor()
	brains[team].reset()
	home_points[team] = actors[team].position
	home_regions[team] = territory.region_at(team, actors[team].position)
	if team != 0:
		hud.show_toast("%s is heading home!" % ("Red" if team == 1 else "Yellow"))

func _captured(team: int, gain: float, at: Vector2) -> void:
	popups.append({"position": at, "text": "+%.1f%%" % (gain * 100), "life": 1.4, "team": team})
	if team == 0:
		hud.show_toast("Nice loop! +%.1f%% island claimed" % (gain * 100))
	if territory.fractions[team] >= config.win_fraction:
		winning_team = team
		_set_state(State.ROUND_OVER)

func pause_round() -> void:
	if state == State.PLAYING:
		_set_state(State.PAUSED)

func resume_round() -> void:
	if state == State.PAUSED:
		_set_state(State.PLAYING)

func _back() -> void:
	match state:
		State.SELECTION:
			get_tree().quit()
		State.PLAYING:
			pause_round()
		State.PAUSED:
			resume_round()
		State.ROUND_OVER, State.DEFEATED:
			choose_country()
		State.DEMO_AD:
			cancel_revive()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_back()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud):
		pause_round()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(hud):
		_back()

func _process(delta: float) -> void:
	if not running:
		return
	for popup in popups:
		popup.life -= delta
		popup.position.y -= delta * 24
	popups = popups.filter(func(p: Dictionary) -> bool: return p.life > 0)
	if is_instance_valid(feedback):
		feedback.queue_redraw()

func _draw_feedback() -> void:
	for popup in popups:
		var tint: Color = config.team_colors[int(popup.team)].darkened(0.4)
		tint.a = minf(1, popup.life)
		feedback.draw_string(hud.font, popup.position - Vector2(25, 50), popup.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 27, tint)

func _capture_preview() -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(preview_path)
	print("PREVIEW_SAVED ", preview_path, " error=", error)
	get_tree().quit(0 if error == OK else 1)

func begin_revive() -> void:
	if state != State.DEFEATED:
		return
	_set_state(State.DEMO_AD)
	hud.demo_remaining = 5
	reward_token = reward.begin()
func cancel_revive() -> void:
	if state != State.DEMO_AD:
		return
	reward.cancel()
	reward_token = -1
	_set_state(State.DEFEATED)
func _reward_completed(token: int) -> void:
	if state != State.DEMO_AD or token != reward_token:
		return
	reward_token = -1
	var actor: ConquerCharacter = actors[0]
	if territory.regions[0].is_empty():
		var patch: PackedVector2Array = IslandGeometry.blob(config.spawn_points[0], Vector2.ONE * 80)
		territory.regions[0] = Geometry2D.intersect_polygons(patch, island)
		for piece in territory.regions[0]:
			territory._remove_from_others(0, piece)
		territory._update_fractions()
	var safe: Vector2 = config.spawn_points[0]
	var distance: float = INF
	for piece in territory.regions[0]:
		var candidate: Vector2 = IslandGeometry.interior_point(piece)
		if candidate.distance_to(actor.position) < distance:
			distance = candidate.distance_to(actor.position)
			safe = candidate
	actor.position = safe
	actor.previous = safe
	actor.trail.clear()
	actor.protection = 3.0
	home_points[0] = safe
	home_regions[0] = territory.region_at(0, safe)
	_set_state(State.PLAYING)

func eliminate_bot(team: int, attacker: int = -1) -> void:
	if team <= 0 or not actors[team].active:
		return
	actors[team].active = false
	actors[team].hide()
	actors[team].trail.clear()
	actors[team].velocity = Vector2.ZERO
	brains[team].reset()
	var before: float = territory.fractions[attacker] if attacker >= 0 else 0
	if attacker >= 0 and actors[attacker].active:
		territory.regions[attacker].append_array(territory.regions[team])
		territory.regions[attacker] = IslandGeometry.merge_regions(territory.typed(territory.regions[attacker]))
	territory.regions[team] = []
	territory._update_fractions()
	if attacker >= 0 and actors[attacker].active:
		_captured(attacker, territory.fractions[attacker] - before, actors[attacker].position)
