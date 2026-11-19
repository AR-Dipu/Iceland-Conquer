class_name WorldCampaignSelector
extends Control
signal country_selected(country_id: String)
signal difficulty_changed(value: int)
signal play_requested
signal bonus_requested(country_id: String)
var catalog: CountryCatalog
var campaign: CampaignProgress
var wallet: PracticeWallet
var bonus_button: Button
var selected: CountryMap
var font: FontVariation
var message: String = ""
var play_button: Button
var name_edit: LineEdit
var name_display: Label
var edit_button: Button
var save_button: Button
var cancel_button: Button
var editing_name: bool = false
var continent_borders: Array = []
var continent_lines := PackedVector2Array()
var multitouch: bool = false
var first_choice_made: bool = false
var zoom: float = 1
var pan := Vector2.ZERO
var fingers: Dictionary = {}
var pinch: float = 0
var dragging := false
var distance: float = 0
var pulse: float = 0
var redraw_clock: float = 0
var geometry_cache: Dictionary = {}
var cache_transform := Vector3.INF
var difficulties: Array[Button] = []
const MAP := Rect2(28,250,664,700)

func setup(data: CountryCatalog, typeface: FontVariation) -> void:
	catalog = data
	font = typeface
	size = Vector2(720,1280)
	name_edit = LineEdit.new()
	name_edit.position = Vector2(28,170)
	name_edit.size = Vector2(370,54)
	name_edit.text = campaign.player_name
	name_edit.max_length = 16
	add_child(name_edit)
	save_button = button("SAVE",Rect2(412,170,130,54),save_name)
	cancel_button = button("CANCEL",Rect2(552,170,140,54),cancel_name)
	name_edit.text_submitted.connect(func(_value: String) -> void: save_name())
	name_display = Label.new()
	name_display.position = Vector2(28,176)
	name_display.size = Vector2(440,48)
	name_display.add_theme_font_override("font",font)
	name_display.add_theme_font_size_override("font_size",27)
	add_child(name_display)
	edit_button = button("",Rect2(478,170,58,54),begin_name_edit)
	edit_button.tooltip_text = "Edit name"
	edit_button.draw.connect(func() -> void:
		edit_button.draw_line(Vector2(18,36),Vector2(39,15),Color("fff0bc"),5,true)
		edit_button.draw_line(Vector2(16,40),Vector2(23,38),Color("fff0bc"),2,true))
	set_name_mode(not campaign.name_saved)
	if FileAccess.file_exists("res://assets/maps/continent_borders.json"):
		continent_borders = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/continent_borders.json"))
	for i in 3:
		var value: int = i
		difficulties.append(button(["EASY · 3","MEDIUM · 5","HARD · 7"][i],Rect2(28+i*226,1050,212,48),func() -> void: difficulty(value)))
	play_button = button("PLAY",Rect2(28,1115,664,77),func() -> void:
		if can_play(): play_requested.emit())
	bonus_button = button("DEMO · CLAIM +225",Rect2(350,968,342,52),func() -> void: bonus_requested.emit(selected.country_id))
	button("+",Rect2(624,270,48,48),func() -> void: zoom_at(zoom*1.3,MAP.get_center()))
	button("−",Rect2(624,328,48,48),func() -> void: zoom_at(zoom/1.3,MAP.get_center()))
	difficulty(0)
	var initial := "bgd"
	if not campaign.starting.is_empty(): initial = campaign.starting
	if not campaign.conquered.is_empty():
		for country in catalog.maps:
			if campaign.can_attack(country.country_id,catalog):
				initial = country.country_id
				break
	select(initial)
	if campaign.starting.is_empty() and campaign.conquered.is_empty(): message = "Choose your country: tap the map, then confirm."

func can_play() -> bool:
	return selected != null and campaign.can_attack(selected.country_id,catalog) and (not campaign.starting.is_empty() or not campaign.conquered.is_empty() or first_choice_made)

func difficulty(value: int) -> void:
	for i in difficulties.size(): difficulties[i].add_theme_stylebox_override("normal",box(Color("884ddd") if i == value else Color("14546f")))
	difficulty_changed.emit(value)

func set_name_mode(edit: bool) -> void:
	editing_name = edit
	name_edit.visible = edit
	save_button.visible = edit
	cancel_button.visible = edit and campaign.name_saved
	name_display.visible = not edit
	edit_button.visible = not edit
	name_display.text = campaign.player_name
	name_edit.text = campaign.player_name

func begin_name_edit() -> void:
	set_name_mode(true)
	name_edit.grab_focus()
	name_edit.select_all()

func save_name() -> void:
	if not campaign.set_name(name_edit.text):
		message = "Name must be 1–16 characters; save must succeed."
		return
	name_edit.release_focus()
	set_name_mode(false)
	message = "Name saved"

func cancel_name() -> void:
	name_edit.release_focus()
	set_name_mode(false)
	message = ""

func zoom_at(value: float, point: Vector2) -> void:
	var before := (point-MAP.get_center()-pan)/zoom
	zoom = clampf(value,1,8)
	pan = point-MAP.get_center()-before*zoom
	pan = pan.clamp(-MAP.size*(zoom-1)*0.5,MAP.size*(zoom-1)*0.5)

func select(id: String) -> void:
	var country := catalog.find(id)
	if country == null: return
	selected = country
	country_selected.emit(id)
	play_button.disabled = not can_play()
	bonus_button.visible = wallet != null and wallet.claimed("country:"+id) and not wallet.claimed("bonus:"+id)
	play_button.text = "CONQUERED" if campaign.conquered.has(id) else "PLAY · "+country.display_name if not play_button.disabled else "LOCKED · CONQUER A NEIGHBOR"
	if campaign.starting.is_empty() and campaign.conquered.is_empty(): play_button.text = "CONFIRM · "+country.display_name if first_choice_made else "CHOOSE YOUR COUNTRY ON THE MAP"
	message = ""
	if play_button.disabled and not campaign.conquered.has(id):
		var names: Array[String] = []
		for n in country.neighbors:
			var neighbor := catalog.find(n)
			if neighbor != null: names.append(neighbor.display_name)
		message = "Connected to: " + ", ".join(names.slice(0,4))

func box(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("46bacd")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.shadow_size = 7
	style.shadow_color = Color(0,0.06,0.15,0.3)
	return style

func button(label: String, rect: Rect2, action: Callable) -> Button:
	var control := Button.new()
	control.text = label
	control.position = rect.position
	control.size = rect.size
	control.focus_mode = Control.FOCUS_NONE
	control.add_theme_font_override("font",font)
	control.add_theme_font_size_override("font_size",19)
	control.add_theme_stylebox_override("normal",box(Color("14546f")))
	control.add_theme_stylebox_override("hover",box(Color("884ddd")))
	control.add_theme_stylebox_override("pressed",box(Color("6036aa")))
	control.pressed.connect(action)
	add_child(control)
	return control

func _process(delta: float) -> void:
	if not visible: return
	pulse += delta
	redraw_clock += delta
	if redraw_clock >= 0.08:
		redraw_clock = 0
		queue_redraw()

func world_point(p: Vector2) -> Vector2:
	# Mercator projection keeps country shapes recognizable in the taller map.
	var latitude: float = clampf(p.y,-60,85)
	var mercator: float = log(tan(PI*0.25+deg_to_rad(latitude)*0.5))
	var base := Vector2(p.x/360*MAP.size.x,-mercator*MAP.size.x/TAU)
	return MAP.get_center()+base*zoom+pan

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if not MAP.has_point(event.position): return
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed: zoom_at(zoom*(1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1/1.2),event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if event.pressed: distance = 0
			elif distance < 10: pick(event.position)
	elif event is InputEventMouseMotion and dragging:
		pan += event.relative
		distance += event.relative.length()
	elif event is InputEventScreenTouch:
		if event.pressed and MAP.has_point(event.position):
			if fingers.is_empty(): multitouch = false
			fingers[event.index] = event.position
			if fingers.size() > 1: multitouch = true
			distance = 0
		else:
			if fingers.has(event.index) and fingers.size() == 1 and distance < 10 and not multitouch: pick(event.position)
			fingers.erase(event.index)
		pinch = 0
	elif event is InputEventScreenDrag and fingers.has(event.index):
		var before_values := fingers.values()
		var old_center: Vector2 = (before_values[0]+before_values[1])*0.5 if before_values.size() > 1 else before_values[0]
		var old_distance: float = before_values[0].distance_to(before_values[1]) if before_values.size() > 1 else 0
		var old: Vector2 = fingers[event.index]
		fingers[event.index] = event.position
		distance += old.distance_to(event.position)
		if fingers.size() == 1: pan += event.position-old
		else:
			var values := fingers.values()
			var length: float = values[0].distance_to(values[1])
			var center: Vector2 = (values[0]+values[1])*0.5
			if old_distance > 0:
				zoom_at(zoom*length/old_distance,old_center)
				pan += center-old_center
			pinch = length
	pan = pan.clamp(-MAP.size*(zoom-1)*0.5,MAP.size*(zoom-1)*0.5)
	accept_event()

func pick(point: Vector2) -> void:
	if not MAP.has_point(point): return
	var nearest_country: CountryMap = null
	var best: float = 12.0
	for country in catalog.maps:
		for ring in country.map_rings:
			var polygon := PackedVector2Array()
			for p in ring: polygon.append(world_point(Vector2(p[0],p[1])))
			if Geometry2D.is_point_in_polygon(point,polygon):
				first_choice_made = true
				select(country.country_id)
				return
			for i in polygon.size():
				var d: float = point.distance_to(Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()]))
				if d < best:
					best = d
					nearest_country = country
	if nearest_country != null:
		first_choice_made = true
		select(nearest_country.country_id)

func text(value: String, point: Vector2, pixels: int, tint: Color = Color("edfcff")) -> void:
	draw_string(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,tint)

func _draw() -> void:
	if catalog == null: return
	text("ISLAND CONQUER",Vector2(28,77),43,Color("ffe49a"))
	text("WORLD CAMPAIGN · %d / %d CONQUERED" % [campaign.conquered.size(),catalog.maps.size()],Vector2(30,120),18,Color("bcf5ee"))
	if wallet != null: text("%d COINS" % wallet.balance,Vector2(535,155),15,Color("ffe49a"))
	text("YOUR NAME",Vector2(30,155),13,Color("cbb5ff"))
	draw_style_box(box(Color("07536d")),MAP)
	var rect_poly := PackedVector2Array([MAP.position,Vector2(MAP.end.x,MAP.position.y),MAP.end,Vector2(MAP.position.x,MAP.end.y)])
	var transform_key := Vector3(pan.x,pan.y,zoom)
	if transform_key != cache_transform:
		geometry_cache.clear()
		cache_transform = transform_key
		continent_lines.clear()
		for line in continent_borders:
			for i in line.size()-1:
				var a := world_point(Vector2(line[i][0],line[i][1]))
				var b := world_point(Vector2(line[i+1][0],line[i+1][1]))
				if MAP.has_point(a) and MAP.has_point(b):
					continent_lines.append(a)
					continent_lines.append(b)
	for country in catalog.maps:
		var owned := campaign.conquered.has(country.country_id)
		var available := campaign.can_attack(country.country_id,catalog)
		var color := Color("9b5cff") if owned else Color("80dba6") if available else Color("3d7e8f")
		if country == selected: color = color.lightened(0.16+sin(pulse*2)*0.05)
		if not geometry_cache.has(country.country_id):
			var pieces: Array[PackedVector2Array] = []
			for ring in country.map_rings:
				var polygon := PackedVector2Array()
				for p in ring: polygon.append(world_point(Vector2(p[0],p[1])))
				for piece in Geometry2D.intersect_polygons(polygon,rect_poly):
					if not Geometry2D.triangulate_polygon(piece).is_empty(): pieces.append(piece)
			geometry_cache[country.country_id] = pieces
		for piece in geometry_cache[country.country_id]:
			draw_colored_polygon(piece,color)
			var border: PackedVector2Array = piece.duplicate()
			border.append(piece[0])
			draw_polyline(border,Color("dcffe5") if country == selected else Color(0.1,0.3,0.4,0.55),1.5 if country == selected else 0.6,true)
	if not continent_lines.is_empty(): draw_multiline(continent_lines,Color("c4efe1"),2.2,true)
	if selected != null:
		for id in selected.sea_neighbors:
			var neighbor := catalog.find(id)
			if neighbor == null: continue
			var a := world_point(Vector2(selected.longitude,selected.latitude))
			var b := world_point(Vector2(neighbor.longitude,neighbor.latitude))
			if not MAP.has_point(a) or not MAP.has_point(b): continue
			for i in 12: draw_circle(a.lerp(b,float(i)/12),2+sin(pulse*3-i)*0.5,Color("ffe6a0"))
		text(selected.display_name.left(22 if bonus_button.visible else 34),Vector2(30,1000),26,Color("ffe49a"))
	text(message.left(80),Vector2(30,1030),14,Color("cfece9"))
	text("TAP A COUNTRY · DRAG / PINCH TO EXPLORE",Vector2(42,932),13)
	text("Conquer neighbors. Follow sea routes. Rule the world.",Vector2(30,1230),17,Color("c8efed"))
