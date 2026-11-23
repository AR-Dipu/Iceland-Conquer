class_name GameHUD
extends Control
signal coin_revive_requested
signal bonus_requested
var coin_balance: int = 0
var earned_coins: Dictionary = {}
var reward_motion := 0.0
var stamp_motion := 0.0
var event_audio: AudioStreamPlayer
var event_sounds: Dictionary = {}

func play_event(event: String) -> void:
	if DisplayServer.get_name() == "headless": return
	if not is_instance_valid(event_audio) or not event_sounds.has(event): return
	event_audio.stream = event_sounds[event]
	event_audio.play()

func _prepare_event_audio() -> void:
	event_audio = AudioStreamPlayer.new()
	event_audio.volume_db = -19
	add_child(event_audio)
	var motifs := {"capture":[440,660],"defeat":[349,233],"revive":[330,494,740],"victory":[392,523,659,784]}
	for key in motifs:
		var data := PackedByteArray()
		for note in motifs[key]:
			for i in 1764:
				var t := float(i)/22050.0
				var envelope := minf(1.0,i/100.0)*pow(1.0-i/1764.0,1.4)
				data.append(int(clampf(128+sin(TAU*note*t)*envelope*42,0,255)))
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_8_BITS
		stream.mix_rate = 22050
		stream.data = data
		event_sounds[key] = stream

func add_reward(reason: String, amount: int) -> void:
	earned_coins[reason] = amount
	reward_motion = 1.0
	queue_redraw()
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
	coin_button.text = "REVIVE — %d COINS" % coin_price
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
var minimap_motion: Node2D
var minimap_land := PackedVector2Array()
var minimap_land_mesh: ArrayMesh
var minimap_outline_hash: int = -1
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
var country_banner: CountryBanner
var modal_banner: CountryBanner

func setup(settings: GameConfig) -> void:
	config = settings
	theme = ConquestTheme.get_theme()
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
	_prepare_event_audio()
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
	status_blocker.size = Vector2(720, 250)
	status_blocker.mouse_filter = MOUSE_FILTER_STOP
	add_child(status_blocker)
	var minimap_blocker := Control.new()
	minimap_blocker.position = Vector2(522, 260)
	minimap_blocker.size = Vector2(174, 219)
	minimap_blocker.mouse_filter = MOUSE_FILTER_STOP
	add_child(minimap_blocker)
	pause_button = make_button("II", Rect2(576, 4, 136, 136), func() -> void: pause_requested.emit())
	resume_button = make_button("BACK TO BATTLE", Rect2(150, 656, 420, 64), func() -> void: resume_requested.emit())
	replay_button = make_button("START CONQUEST", Rect2(150, 737, 420, 64), func() -> void: restart_requested.emit())
	country_button = make_button("WORLD MAP", Rect2(150, 818, 420, 64), func() -> void: choose_country_requested.emit())
	revive_button = make_button("DEMO AD & REVIVE", Rect2(110, 807, 500, 70), func() -> void: revive_requested.emit())
	revive_button.add_theme_font_size_override("font_size", 21)
	cancel_button = make_button("CANCEL", Rect2(150, 787, 420, 64), func() -> void: cancel_ad_requested.emit())
	coin_button = make_button("RESUME WITH COINS", Rect2(110, 717, 500, 62), func() -> void: coin_revive_requested.emit())
	coin_button.add_theme_font_size_override("font_size", 21)
	bonus_button = make_button("DEMO AD: 250 COINS TOTAL", Rect2(110, 859, 500, 55), func() -> void: bonus_requested.emit())
	bonus_button.add_theme_font_size_override("font_size", 20)
	country_banner = CountryBanner.new()
	country_banner.position = Vector2(24,18)
	country_banner.size = Vector2(540,112)
	add_child(country_banner)
	modal_banner = CountryBanner.new()
	modal_banner.position = Vector2(96,256)
	modal_banner.size = Vector2(528,112)
	add_child(modal_banner)
	set_mode("selection")

func box(color: Color, edge: Color = Color(0.5, 0.9, 1, 0.4)) -> StyleBoxFlat:
	return ConquestTheme.panel(color,edge)

func make_button(label: String, rect: Rect2, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.position = rect.position
	button.size = rect.size
	ConquestTheme.style_button(button,label in ["BACK TO BATTLE","START CONQUEST","DEMO AD & REVIVE"])
	button.pressed.connect(action)
	button.pressed.connect(func() -> void: click_audio.play())
	add_child(button)
	return button

func bind_world(country: CountryMap, territories: TerritoryManager, characters: Array[ConquerCharacter], view: Camera2D) -> void:
	if is_instance_valid(territory) and territory.mesh_published.is_connected(queue_redraw):
		territory.mesh_published.disconnect(queue_redraw)
	map = country
	territory = territories
	territory.mesh_published.connect(queue_redraw)
	if minimap_motion == null:
		minimap_motion = Node2D.new()
		minimap_motion.draw.connect(_draw_minimap_motion)
		add_child(minimap_motion)
	actors = characters
	camera = view
	country_banner.set_country(country,"WORLD CONQUEST")
	modal_banner.set_country(country,"MAKE YOUR NEXT MOVE")
	update_scores(territories.fractions)

func update_scores(values: Array[float]) -> void:
	fractions = values.duplicate()
	queue_redraw()

func set_mode(value: String, winning_team: int = -1) -> void:
	if value == "round_over" and mode == "playing": stamp_motion = 1.0
	if popup_tween != null: popup_tween.kill()
	modulate.a = 0.3 if value in ["defeated","round_over","paused"] else 1.0
	if modulate.a < 1:
		popup_tween = create_tween()
		popup_tween.tween_property(self,"modulate:a",1.0,0.16).set_trans(Tween.TRANS_SINE)
	mode = value
	if is_instance_valid(minimap_motion): minimap_motion.visible = value == "playing"
	winner = winning_team
	visible = value != "selection" and value != "loading"
	mobile.enabled = value == "playing"
	mobile.release()
	blocker.visible = value in ["paused", "round_over", "defeated", "demo_ad"]
	pause_button.visible = value == "playing"
	resume_button.visible = value == "paused"
	revive_button.visible = value == "defeated"
	cancel_button.visible = value == "demo_ad"
	replay_button.text = "RESTART — FREE" if value in ["defeated","paused"] else "PLAY AGAIN"
	country_button.text = "WORLD MAP"
	replay_button.visible = blocker.visible and value != "demo_ad"
	country_button.visible = blocker.visible and value != "demo_ad"
	coin_button.visible = value == "defeated"
	modal_banner.visible = blocker.visible
	country_banner.visible = not blocker.visible
	for button in [resume_button,replay_button,country_button,revive_button,coin_button,bonus_button,cancel_button]:
		button.position.x = 96
		button.size = Vector2(528,136)
	resume_button.position.y = 544
	revive_button.position.y = 544
	coin_button.position.y = 688
	replay_button.position.y = 832 if value == "defeated" else 688 if value == "paused" else 544
	country_button.position.y = 976 if value == "defeated" else 832 if value == "paused" else 688
	bonus_button.position.y = 832
	cancel_button.position.y = 832
	refresh_economy()
	queue_redraw()

func show_toast(value: String) -> void:
	toast = value
	toast_life = 2.4
	queue_redraw()

func _process(delta: float) -> void:
	if mode == "round_over" and reward_motion > 0:
		reward_motion = move_toward(reward_motion,0.0,delta*3.5)
		queue_redraw()
	if mode == "round_over" and stamp_motion > 0:
		stamp_motion = move_toward(stamp_motion,0.0,delta*4.0)
		queue_redraw()
	var previous_toast := toast_life
	toast_life = maxf(0, toast_life - delta)
	if previous_toast > 0 and toast_life == 0: queue_redraw()
	redraw_clock += delta
	if visible and redraw_clock > 0.05:
		redraw_clock = 0
		if is_instance_valid(minimap_motion) and mode == "playing": minimap_motion.queue_redraw()

func text(value: String, point: Vector2, pixels: int, tint: Color = Color("effcff"), centered: bool = false) -> void:
	if centered:
		point.x -= font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x * 0.5
	draw_string(font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, tint)

func minimap_transform() -> Transform2D:
	if map == null:
		return Transform2D.IDENTITY
	var rect := Rect2(539, 289, 140, 164)
	var factor: float = minf(rect.size.x / map.land_bounds.size.x, rect.size.y / map.land_bounds.size.y)
	return Transform2D(0, Vector2.ONE * factor, 0, rect.get_center() - map.land_bounds.get_center() * factor)

func _minimap() -> void:
	var began := WorkMetrics.start()
	draw_style_box(box(ConquestTheme.PANEL), Rect2(522, 260, 174, 219))
	text("COUNTRY MAP", Vector2(609, 283), 12, Color("c9ecf0"), true)
	var transform: Transform2D = minimap_transform()
	var outline_hash: int = hash([map.outline,transform])
	if minimap_outline_hash != outline_hash:
		minimap_outline_hash = outline_hash
		minimap_land = transform*map.outline
		minimap_land_mesh = minimap_mesh(minimap_land,Geometry2D.triangulate_polygon(map.outline))
	if minimap_land_mesh != null: draw_mesh(minimap_land_mesh,null,Transform2D.IDENTITY,Color("dfcea1"))
	var snapshot: Array = territory.render_snapshot()
	for team in snapshot.size():
		for piece in snapshot[team].pieces:
			if not piece.indices.is_empty(): draw_mesh(piece.mesh,null,transform,config.team_colors[team])
	text(actor_name(0), Vector2(609, 467), 11, Color("dcc2ff"), true)
	WorkMetrics.finish("minimap",began)

func _draw_minimap_motion() -> void:
	if map == null or not is_instance_valid(territory): return
	var transform := minimap_transform()
	if is_instance_valid(camera):
		var frame := minimap_camera_polygon()
		var clip := PackedVector2Array([Vector2(539,289),Vector2(679,289),Vector2(679,453),Vector2(539,453)])
		for piece in Geometry2D.intersect_polygons(frame,clip):
			piece.append(piece[0])
			minimap_motion.draw_polyline(piece,Color(0.85,1,1,0.65),1,true)
	for actor in actors:
		if not actor.active:
			continue
		var point: Vector2 = transform * actor.position
		if not Rect2(539,289,140,164).has_point(point): continue
		minimap_motion.draw_circle(point, 4.3 if actor.team == 0 else 3.5, Color.WHITE)
		minimap_motion.draw_circle(point, 3.1 if actor.team == 0 else 2.5, config.team_colors[actor.team])

func minimap_mesh(points: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	if indices.is_empty(): return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func minimap_camera_polygon() -> PackedVector2Array:
	var size: Vector2 = get_viewport_rect().size
	var inverse := get_viewport().get_canvas_transform().affine_inverse()
	var transform := minimap_transform()
	return PackedVector2Array([transform*(inverse*Vector2.ZERO),transform*(inverse*Vector2(size.x,0)),transform*(inverse*size),transform*(inverse*Vector2(0,size.y))])

func _draw() -> void:
	if config == null or map == null or not is_instance_valid(territory):
		return
	draw_style_box(ConquestTheme.panel(),Rect2(24,142,672,96))
	text(actor_name(0).to_upper(),Vector2(44,171),17,ConquestTheme.CREAM)
	text("%d%%" % display_percent(0),Vector2(44,218),34,ConquestTheme.GOLD)
	draw_style_box(box(Color("101b31"),Color.TRANSPARENT),Rect2(161,193,252,16))
	if fractions[0] > 0: draw_style_box(box(Color("9b5cff"),Color.TRANSPARENT),Rect2(161,193,252*minf(1,fractions[0]/config.win_fraction),16))
	text("COUNTRY CONTROL",Vector2(161,227),12,ConquestTheme.MUTED)
	var remaining: int = actors.filter(func(a: ConquerCharacter) -> bool: return a.team > 0 and a.active).size()
	text(difficulty_name,Vector2(476,176),16,ConquestTheme.GOLD)
	text("%d RIVALS LEFT" % remaining,Vector2(476,217),16)
	_minimap()
	draw_style_box(box(Color(0.015, 0.20, 0.31, 0.82)), Rect2(65, 1165, 590, 66))
	text("TOUCH AND HOLD TO MOVE", Vector2(360, 1191), 17, Color("e3d0ff"), true)
	text("Release to stop. Return to your land to claim area.", Vector2(360, 1216), 15, Color("d4f0f0"), true)
	if toast_life > 0 and mode == "playing":
		draw_style_box(box(Color(0.02, 0.20, 0.31, 0.94)), Rect2(95, 1050, 530, 55))
		text(toast, Vector2(360, 1085), 20, Color("ffe6a1"), true)
	if mode in ["paused", "round_over", "defeated", "demo_ad"]:
		draw_rect(Rect2(-1000, -1600, 3000, 4500), Color(0.01, 0.08, 0.16, 0.78))
		draw_style_box(box(ConquestTheme.INK,ConquestTheme.GOLD), Rect2(72,240,576,960))
		if toast_life > 0: text(toast.left(54),Vector2(360,1170),14,Color("ffe4a0"),true)
		var title: String = "BATTLE PAUSED"
		if mode == "round_over":
			title = "COUNTRY CONQUERED!" if winner == 0 else actor_name(winner).to_upper() + " WINS!"
		if mode == "defeated":
			title = "DEFEATED!"
		elif mode == "demo_ad":
			title = "DEMO REWARDED AD"
		var impact := stamp_motion*stamp_motion if mode == "round_over" else 0.0
		if impact > 0.0:
			draw_arc(Vector2(360,412),35+impact*45,0,TAU,32,Color(ConquestTheme.GOLD,impact*0.8),2,true)
		text(title, Vector2(360,422-impact*7), 31+roundi(impact*5), ConquestTheme.GOLD, true)
		var reward_labels := PackedStringArray()
		if mode == "round_over" and winner == 0:
			for reason in earned_coins: reward_labels.append("%s +%d" % [reason,earned_coins[reason]])
		if mode in ["round_over","defeated"]:
			text("No coins earned" if reward_labels.is_empty() else "  ·  ".join(reward_labels),Vector2(360,466-reward_motion*9),19,ConquestTheme.GOLD,true)
			if not reward_labels.is_empty() and reward_motion > 0:
				for i in 5:
					var progress := 1.0-reward_motion
					var point := Vector2(290+i*35,411.0+progress*49)
					draw_circle(point,3.0+progress*2.0,Color(ConquestTheme.GOLD,reward_motion))
		else:
			text("%s · %d%%" % [actor_name(0),display_percent(0)],Vector2(360,466),20,ConquestTheme.CREAM,true)
		var detail := "MAKE YOUR NEXT MOVE"
		if mode == "demo_ad": detail = "Demo Ad — no real ad is shown. %ds" % ceili(demo_remaining)
		elif mode == "defeated" and coin_balance < coin_price: detail = "NEED %d MORE COINS — OR RESTART FREE" % (coin_price-coin_balance)
		text(detail,Vector2(360,508),17,Color("c8e6eb"),true)
		if mode == "demo_ad":
			draw_circle(Vector2(360,666),72,ConquestTheme.PURPLE)
			draw_arc(Vector2(360,666),73,-PI*0.5,TAU*clampf(demo_remaining/3.0,0,1)-PI*0.5,48,ConquestTheme.GOLD,5,true)
			text(str(ceili(demo_remaining)),Vector2(360,686),56,ConquestTheme.GOLD,true)
			text("WATCH TO REJOIN THE BATTLE",Vector2(360,782),18,ConquestTheme.CREAM,true)
