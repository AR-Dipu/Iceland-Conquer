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
var selector: WorldCampaignSelector
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
var wallet := PracticeWallet.new()
var coin_revives: int = 0
var match_id: String = ""
var active_seconds: float = 0.0
var ad_purpose: String = "revive"
var ad_return: State = State.DEFEATED
var campaign := CampaignProgress.new()
var player_names: Array[String] = []
var profile_path: String = "user://"

func revival_price() -> int:
	return wallet.settings.revival_prices[mini(coin_revives, wallet.settings.revival_prices.size() - 1)]

func _wallet_ui() -> void:
	hud.coin_balance = wallet.balance
	hud.coin_price = revival_price()
	hud.wallet_ready = wallet.healthy
	hud.bonus_ready = wallet.claimed("country:" + selected_country) and not wallet.claimed("bonus:" + selected_country)
	hud.refresh_economy()

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
	wallet.open(profile_path + "practice_wallet.json")
	wallet.daily_login()
	campaign.path = profile_path + "campaign.cfg"
	campaign.open(wallet)
	wallet.changed.connect(func(_balance: int) -> void: _wallet_ui())
	hud.coin_revive_requested.connect(coin_revive)
	hud.bonus_requested.connect(begin_bonus)
	_wallet_ui()
	hud.mobile.movement_released.connect(_stop_player)
	hud.pause_requested.connect(pause_round)
	hud.resume_requested.connect(resume_round)
	hud.restart_requested.connect(start_round)
	hud.choose_country_requested.connect(choose_country)
	hud.revive_requested.connect(begin_revive)
	hud.cancel_ad_requested.connect(cancel_revive)
	selector = WorldCampaignSelector.new()
	selector.campaign = campaign
	selector.wallet = wallet
	ui_root.add_child(selector)
	selector.setup(catalog, hud.font)
	selector.country_selected.connect(_country_selected)
	selector.play_requested.connect(start_round)
	selector.bonus_requested.connect(_claim_pending_bonus)
	selector.difficulty_changed.connect(func(value: int) -> void: difficulty = value; hud.difficulty_name = ["EASY","MEDIUM","HARD"][value])
	selected_country = selector.selected.country_id
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
	selector.play_button.disabled = state == State.LOADING or not campaign.can_attack(selected_country,catalog)
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
	current_map.scenery.clear()
	current_map._build_scenery()
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
	player_names = campaign.round_names(actors.size())
	for actor in actors:
		var label := Label.new()
		label.text = player_names[actor.team]
		label.position = Vector2(-65, -100)
		label.size.x = 130
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", hud.font)
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_shadow_color", Color("123f5d"))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		actor.add_child(label)
	hud.player_names = player_names
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
	var replay: bool = state in [State.PLAYING,State.PAUSED,State.DEFEATED,State.ROUND_OVER] and current_map != null and selected_country == current_map.country_id
	if not replay and not campaign.can_attack(selected_country, catalog):
		selector.message = "Choose a neighboring country to continue."
		return
	if not campaign.begin(selected_country):
		selector.message = "Campaign could not save. Please try again."
		return
	reward.cancel()
	reward_token = -1
	winning_team = -1
	coin_revives = 0
	active_seconds = 0
	match_id = Crypto.new().generate_random_bytes(16).hex_encode()
	if not load_country(selected_country):
		selector.message = "This island could not load. Choose another."
		_set_state(State.SELECTION)
		return
	selector.message = ""
	hud.toast_life = 0
	_set_state(State.PLAYING)
	_wallet_ui()

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
				continue
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

func _home_entry(actor: ConquerCharacter) -> float:
	if territory.owned(actor.team, actor.previous):
		return 0.0
	var distance: float = actor.previous.distance_to(actor.position)
	var result: float = INF
	if distance < 0.001:
		return result
	for polygon in territory.regions[actor.team]:
		for i in polygon.size():
			var hit: Variant = Geometry2D.segment_intersects_segment(actor.previous, actor.position, polygon[i], polygon[(i + 1) % polygon.size()])
			if hit != null:
				result = minf(result, actor.previous.distance_to(hit) / distance)
	return result

func _update_trail(actor: ConquerCharacter) -> void:
	var trail: ConquerTrail = actor.trail
	var entry: float = _home_entry(actor)
	if entry > 0.0 and entry <= 1.0 and not trail.points.is_empty():
		trail.append_point(actor.previous.lerp(actor.position, entry))
		if trail.points.size() > 2:
			territory.capture(actor.team, trail.points, trail.departure)
		trail.clear()
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
		hud.show_toast("%s is heading home!" % player_names[team])

func _captured(team: int, gain: float, at: Vector2) -> void:
	hud.update_scores(territory.fractions)
	popups.append({"position": at, "text": "+%.1f%%" % (gain * 100), "life": 1.4, "team": team})
	if team == 0:
		hud.show_toast("Nice loop! +%.1f%% island claimed" % (gain * 100))
	if territory.fractions[team] >= config.win_fraction:
		if team == 0:
			campaign.conquer(selected_country)
			wallet.transact("country:" + selected_country, wallet.settings.completion_coins)
			if active_seconds >= 120:
				wallet.transact("objective:" + match_id, wallet.settings.objective_coins)
			_wallet_ui()
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
	active_seconds += delta
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
	if _revival_land().is_empty(): return
	ad_purpose = "revive"
	ad_return = State.DEFEATED
	_set_state(State.DEMO_AD)
	hud.demo_remaining = 3
	reward_token = reward.begin()
func cancel_revive() -> void:
	if state != State.DEMO_AD:
		return
	reward.cancel()
	reward_token = -1
	_set_state(ad_return)
func _reward_completed(token: int) -> void:
	if state != State.DEMO_AD or token != reward_token:
		return
	reward_token = -1
	if ad_purpose == "bonus":
		if wallet.claimed("country:" + selected_country):
			wallet.transact("bonus:" + selected_country, wallet.settings.completion_coins * (wallet.settings.multiplier - 1))
		_wallet_ui()
		_set_state(State.ROUND_OVER)
		return
	_revive_player()

func begin_bonus() -> void:
	if state != State.ROUND_OVER or winning_team != 0 or not hud.bonus_ready: return
	ad_purpose = "bonus"
	ad_return = State.ROUND_OVER
	_set_state(State.DEMO_AD)
	hud.demo_remaining = 3
	reward_token = reward.begin()

func _claim_pending_bonus(id: String) -> void:
	if state != State.SELECTION or not wallet.claimed("country:"+id) or wallet.claimed("bonus:"+id): return
	if not load_country(id): return
	winning_team = 0
	_wallet_ui()
	_set_state(State.ROUND_OVER)
	begin_bonus()

func coin_revive() -> void:
	if state != State.DEFEATED: return
	if _revival_land().is_empty(): return
	if not wallet.transact("revive:" + match_id + ":" + str(coin_revives), -revival_price()):
		hud.show_toast("Not enough coins or wallet could not save")
		return
	coin_revives += 1
	_revive_player()
	_wallet_ui()

func _revive_player() -> void:
	var actor: ConquerCharacter = actors[0]
	if territory.regions[0].is_empty():
		territory.regions[0] = _revival_land()
		if territory.regions[0].is_empty():
			_set_state(State.DEFEATED)
			return
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
	actor.protection = wallet.settings.shield_seconds
	home_points[0] = safe
	home_regions[0] = territory.region_at(0, safe)
	_set_state(State.PLAYING)

func _revival_land() -> Array:
	if not territory.regions[0].is_empty(): return territory.regions[0]
	var neutral: Array = [island]
	for team in range(1, territory.regions.size()):
		for owned_piece in territory.regions[team]:
			var remainder: Array = []
			for piece in neutral:
				remainder.append_array(IslandGeometry.subtract(piece, owned_piece))
			neutral = remainder
	for piece in neutral:
		if IslandGeometry.area(piece) < 100: continue
		var point: Vector2 = IslandGeometry.interior_point(piece)
		var patch := IslandGeometry.blob(point, Vector2.ONE * 80)
		var clipped: Array = Geometry2D.intersect_polygons(patch, piece)
		if not clipped.is_empty(): return clipped
	hud.show_toast("No safe neutral land. Restart for free.")
	return []

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
