class_name GameHUD
extends Control
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
	mode = value
	winner = winning_team
	visible = value != "selection" and value != "loading"
	mobile.enabled = value == "playing"
	mobile.release()
	blocker.visible = value == "paused" or value == "round_over"
	pause_button.visible = value == "playing"
	resume_button.visible = value == "paused"
	replay_button.visible = blocker.visible
	country_button.visible = blocker.visible
	replay_button.position.y = 737 if value == "paused" else 687
	country_button.position.y = 818 if value == "paused" else 768
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
	for team in 3:
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
		var point: Vector2 = transform * actor.position
		draw_circle(point, 4.3 if actor.team == 0 else 3.5, Color.WHITE)
		draw_circle(point, 3.1 if actor.team == 0 else 2.5, config.team_colors[actor.team])
	text("YOU ARE PURPLE", Vector2(609, 391), 11, Color("dcc2ff"), true)

func _draw() -> void:
	if config == null or map == null or not is_instance_valid(territory):
		return
	draw_style_box(box(Color(0.015, 0.20, 0.31, 0.94)), Rect2(24, 24, 672, 141))
	text(map.display_name.to_upper(), Vector2(44, 62), 27, Color("ffe5a0"))
	text("YOUR TERRITORY", Vector2(44, 91), 13, Color("c6e8ed"))
	text("%d%%" % roundi(fractions[0] * 100), Vector2(44, 136), 35, Color("e4ceff"))
	draw_style_box(box(Color("123b58"), Color.TRANSPARENT), Rect2(161, 111, 252, 15))
	if fractions[0] > 0:
		draw_style_box(box(Color("9b5cff"), Color.TRANSPARENT), Rect2(161, 111, 252 * minf(1, fractions[0] / config.win_fraction), 15))
	text("60% TO WIN", Vector2(161, 147), 12, Color("ffe5a0"))
	for team in [1, 2]:
		var x: float = 484 + (team - 1) * 100
		draw_circle(Vector2(x, 105), 5, config.team_colors[team])
		text("%d%%" % roundi(fractions[team] * 100), Vector2(x, 140), 23, Color.WHITE, true)
	_minimap()
	draw_style_box(box(Color(0.015, 0.20, 0.31, 0.82)), Rect2(65, 1165, 590, 66))
	text("TOUCH AND HOLD TO MOVE", Vector2(360, 1191), 17, Color("e3d0ff"), true)
	text("Release to stop. Return to purple to claim land.", Vector2(360, 1216), 15, Color("d4f0f0"), true)
	if toast_life > 0 and mode == "playing":
		draw_style_box(box(Color(0.02, 0.20, 0.31, 0.94)), Rect2(95, 1050, 530, 55))
		text(toast, Vector2(360, 1085), 20, Color("ffe6a1"), true)
	if mode == "paused" or mode == "round_over":
		draw_rect(Rect2(-1000, -1600, 3000, 4500), Color(0.01, 0.08, 0.16, 0.78))
		draw_style_box(box(Color("123f5d")), Rect2(95, 413, 530, 510))
		text(map.display_name.to_upper(), Vector2(360, 462), 19, Color("b3e7e2"), true)
		var title: String = "ISLAND TIME"
		if mode == "round_over":
			title = "COUNTRY CONQUERED!" if winner == 0 else "A RIVAL RULES!"
		text(title, Vector2(360, 525), 31, Color("ffe5a0"), true)
		text("Your purple territory: %d%%" % roundi(fractions[0] * 100), Vector2(360, 574), 23, Color("dcc4ff"), true)
		text("A little pause before your next adventure.", Vector2(360, 613), 17, Color("c8e6eb"), true)
