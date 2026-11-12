class_name GameHUD
extends Control
signal coin_revive_requested
signal bonus_requested
var coin_balance: int = 0
var coin_price: int = 100
var wallet_ready: bool = false
var bonus_ready: bool = false
var player_names: Array[String] = []

func actor_name(team: int) -> String:
	return player_names[team] if team >= 0 and team < player_names.size() else "Captain"

func display_percent(team: int) -> int:
	if mode == "round_over" and winner == team: return 100
	return mini(99,floori(fractions[team]*100))
var coin_button: Button
var bonus_button: Button
var popup_tween: Tween
var click_audio: AudioStreamPlayer

func refresh_economy() -> void:
	if coin_button == null: return
	coin_button.text = "RESUME WITH COINS — %d" % coin_price
	coin_button.disabled = not wallet_ready or coin_balance < coin_price
	bonus_button.visible = mode == "round_over" and winner == 0 and bonus_ready
	queue_redraw()
signal revive_requested
signal cancel_ad_requested
var revive_button: Button
var cancel_button: Button
var demo_remaining: float = 3
signal pause_requested
signal resume_requested
signal restart_requested
signal choose_country_requested
var font := FontVariation.new()
var config: GameConfig
var map: CountryMap
var territory: TerritoryManager
var actors: Array[ConquerCharacter] = []
var camera: Camera2D
var difficulty_name: String = "EASY"
var mode: String = "selection"
var winner: int = -1
var fractions: Array[float] = [0, 0, 0]
var mobile: MobileInput
var pause_button: Button
var resume_button: Button
var replay_button: Button
var country_button: Button
var blocker: Control
var toast: String = ""
var toast_life: float = 0
var redraw_clock: float = 0

func setup(settings: GameConfig) -> void:
	config = settings
	click_audio = AudioStreamPlayer.new()
	var tone := AudioStreamWAV.new()
	tone.format = AudioStreamWAV.FORMAT_8_BITS
	tone.mix_rate = 22050
	var samples := PackedByteArray()
	for i in 1323:
		var t: float = float(i)/22050
		samples.append(clampi(roundi(128 + sin(t*TAU*660)*32*(1-float(i)/1323)),0,255))
	tone.data = samples
	click_audio.stream = tone
	click_audio.volume_db = -14
	add_child(click_audio)
	font.base_font = preload("res://assets/fonts/Fredoka.ttf")
	font.variation_opentype = {"wght": 600.0, "wdth": 100.0}
	font.variation_embolden = 0.6
	size = Vector2(720, 1280)
	mouse_filter = MOUSE_FILTER_IGNORE
	mobile = MobileInput.new()
	add_child(mobile)
	blocker = Control.new()
	blocker.position = Vector2.ZERO
	blocker.size = size
	blocker.mouse_filter = MOUSE_FILTER_STOP
	add_child(blocker)
	var status_blocker := Control.new()
	status_blocker.size = Vector2(720, 173)
	status_blocker.mouse_filter = MOUSE_FILTER_STOP
	add_child(status_blocker)
	var minimap_blocker := Control.new()
	minimap_blocker.position = Vector2(522, 184)
	minimap_blocker.size = Vector2(174, 219)
	minimap_blocker.mouse_filter = MOUSE_FILTER_STOP
	add_child(minimap_blocker)
	pause_button = make_button("II", Rect2(624, 35, 62, 60), func() -> void: pause_requested.emit())
	resume_button = make_button("RESUME", Rect2(150, 656, 420, 64), func() -> void: resume_requested.emit())
	replay_button = make_button("PLAY AGAIN", Rect2(150, 737, 420, 64), func() -> void: restart_requested.emit())
	country_button = make_button("CHOOSE COUNTRY", Rect2(150, 818, 420, 64), func() -> void: choose_country_requested.emit())
	revive_button = make_button("WATCH DEMO AD & REVIVE", Rect2(110, 807, 500, 70), func() -> void: revive_requested.emit())
	revive_button.add_theme_font_size_override("font_size", 21)
	cancel_button = make_button("CANCEL", Rect2(150, 787, 420, 64), func() -> void: cancel_ad_requested.emit())
	coin_button = make_button("RESUME WITH COINS", Rect2(110, 717, 500, 62), func() -> void: coin_revive_requested.emit())
	coin_button.add_theme_font_size_override("font_size", 21)
	bonus_button = make_button("DEMO AD: 250 COINS TOTAL", Rect2(110, 859, 500, 55), func() -> void: bonus_requested.emit())
	bonus_button.add_theme_font_size_override("font_size", 20)
	set_mode("selection")

func box(color: Color, edge: Color = Color(0.5, 0.9, 1, 0.4)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	style.shadow_size = 5
	style.shadow_color = Color(0, 0.1, 0.2, 0.15)
	return style

func make_button(label: String, rect: Rect2, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_stylebox_override("normal", box(Color("23527b")))
	button.add_theme_stylebox_override("hover", box(Color("8050cf")))
	button.add_theme_stylebox_override("pressed", box(Color("523185")))
	button.pressed.connect(action)
	button.pressed.connect(func() -> void: click_audio.play())
	add_child(button)
	return button

func bind_world(country: CountryMap, territories: TerritoryManager, characters: Array[ConquerCharacter], view: Camera2D) -> void:
	map = country
	territory = territories
	actors = characters
	camera = view
	update_scores(territories.fractions)

func update_scores(values: Array[float]) -> void:
	fractions = values.duplicate()
	queue_redraw()

func set_mode(value: String, winning_team: int = -1) -> void:
	if popup_tween != null: popup_tween.kill()
	modulate.a = 0.3 if value in ["defeated","round_over","paused"] else 1.0
	if modulate.a < 1:
		popup_tween = create_tween()
		popup_tween.tween_property(self,"modulate:a",1.0,0.22).set_trans(Tween.TRANS_SINE)
	mode = value
	winner = winning_team
	visible = value != "selection" and value != "loading"
	mobile.enabled = value == "playing"
	mobile.release()
	blocker.visible = value in ["paused", "round_over", "defeated", "demo_ad"]
	pause_button.visible = value == "playing"
	resume_button.visible = value == "paused"
	revive_button.visible = value == "defeated"
	cancel_button.visible = value == "demo_ad"
	replay_button.text = "REPLAY" if value == "defeated" else "PLAY AGAIN"
	country_button.text = "HOME" if value == "defeated" else "CHOOSE COUNTRY"
	replay_button.visible = blocker.visible and value != "demo_ad"
	country_button.visible = blocker.visible and value != "demo_ad"
	replay_button.position.y = 737 if value == "paused" else 687
	country_button.position.y = 818 if value == "paused" else 768
	if value == "defeated":
		revive_button.position.y = 637
		replay_button.position.y = 797
		replay_button.text = "RESTART FOR FREE"
		country_button.position.y = 877
	coin_button.visible = value == "defeated"
	refresh_economy()
	queue_redraw()

func show_toast(value: String) -> void:
	toast = value
	toast_life = 2.4
	queue_redraw()

func _process(delta: float) -> void:
	toast_life = maxf(0, toast_life - delta)
	redraw_clock += delta
	if visible and redraw_clock > 0.05:
		redraw_clock = 0
		queue_redraw()

func text(value: String, point: Vector2, pixels: int, tint: Color = Color("effcff"), centered: bool = false) -> void:
	if centered:
		point.x -= font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x * 0.5
	draw_string(font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, tint)

func minimap_transform() -> Transform2D:
	if map == null:
		return Transform2D.IDENTITY
	var rect := Rect2(539, 213, 140, 164)
	var factor: float = minf(rect.size.x / map.land_bounds.size.x, rect.size.y / map.land_bounds.size.y)
	return Transform2D(0, Vector2.ONE * factor, 0, rect.get_center() - map.land_bounds.get_center() * factor)

func _minimap() -> void:
	draw_style_box(box(Color(0.015, 0.20, 0.31, 0.91)), Rect2(522, 184, 174, 219))
	text("ISLAND MAP", Vector2(609, 207), 12, Color("c9ecf0"), true)
	var transform: Transform2D = minimap_transform()
	draw_colored_polygon(transform * map.outline, Color("a9ce70"))
	for team in territory.regions.size():
		for p in territory.regions[team]:
			draw_colored_polygon(transform * p, config.team_colors[team])
	if is_instance_valid(camera):
		var world_size: Vector2 = get_viewport_rect().size / camera.zoom
		var frame := Rect2(camera.get_screen_center_position() - world_size * 0.5, world_size)
		var visual := Rect2(transform * frame.position, frame.size * transform.get_scale())
		visual = visual.intersection(Rect2(534, 212, 150, 168))
		if visual.has_area():
			draw_rect(visual, Color(0.85, 1, 1, 0.55), false, 1.0)
	for actor in actors:
		if not actor.active:
			continue
		var point: Vector2 = transform * actor.position
		draw_circle(point, 4.3 if actor.team == 0 else 3.5, Color.WHITE)
		draw_circle(point, 3.1 if actor.team == 0 else 2.5, config.team_colors[actor.team])
	text(actor_name(0), Vector2(609, 391), 11, Color("dcc2ff"), true)

func _draw() -> void:
	if config == null or map == null or not is_instance_valid(territory):
		return
	draw_style_box(box(Color(0.015, 0.20, 0.31, 0.94)), Rect2(24, 24, 672, 141))
	text(map.display_name.to_upper(), Vector2(44, 62), 27, Color("ffe5a0"))
	text(actor_name(0).to_upper(), Vector2(44, 91), 13, Color("c6e8ed"))
	text("%d%%" % display_percent(0), Vector2(44, 136), 35, Color("e4ceff"))
	draw_style_box(box(Color("123b58"), Color.TRANSPARENT), Rect2(161, 111, 252, 15))
	if fractions[0] > 0:
		draw_style_box(box(Color("9b5cff"), Color.TRANSPARENT), Rect2(161, 111, 252 * minf(1, fractions[0] / config.win_fraction), 15))
	text("100% TO WIN", Vector2(161, 147), 12, Color("ffe5a0"))
	var remaining: int = actors.filter(func(a: ConquerCharacter) -> bool: return a.team > 0 and a.active).size()
	text(difficulty_name, Vector2(476,105),16)
	text("%d RIVALS LEFT" % remaining, Vector2(476,140),16)
	_minimap()
	draw_style_box(box(Color(0.015, 0.20, 0.31, 0.82)), Rect2(65, 1165, 590, 66))
	text("TOUCH AND HOLD TO MOVE", Vector2(360, 1191), 17, Color("e3d0ff"), true)
	text("Release to stop. Return to your land to claim area.", Vector2(360, 1216), 15, Color("d4f0f0"), true)
	if toast_life > 0 and mode == "playing":
		draw_style_box(box(Color(0.02, 0.20, 0.31, 0.94)), Rect2(95, 1050, 530, 55))
		text(toast, Vector2(360, 1085), 20, Color("ffe6a1"), true)
	if mode in ["paused", "round_over", "defeated", "demo_ad"]:
		draw_rect(Rect2(-1000, -1600, 3000, 4500), Color(0.01, 0.08, 0.16, 0.78))
		draw_style_box(box(Color("123f5d")), Rect2(95, 413, 530, 550))
		if toast_life > 0: text(toast.left(54),Vector2(360,952),14,Color("ffe4a0"),true)
		text(map.display_name.to_upper(), Vector2(360, 462), 19, Color("b3e7e2"), true)
		var title: String = "ISLAND TIME"
		if mode == "round_over":
			title = actor_name(winner) + " WINS!"
		if mode == "defeated":
			title = "Your tail was cut!"
		elif mode == "demo_ad":
			title = "Demo rewarded ad"
		text(title, Vector2(360, 525), 31, Color("ffe5a0"), true)
		text("COINS: %d  |  %s: %d%%" % [coin_balance, actor_name(winner if mode == "round_over" else 0), display_percent(winner if mode == "round_over" else 0)], Vector2(360, 574), 20, Color("dcc4ff"), true)
		text("No real ad is shown. %d seconds left" % ceili(demo_remaining) if mode == "demo_ad" else "Choose your next adventure.", Vector2(360, 613), 17, Color("c8e6eb"), true)
