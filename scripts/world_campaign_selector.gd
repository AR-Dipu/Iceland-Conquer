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
var list: ItemList
var search: LineEdit
var continent: OptionButton
var listed: Array[String] = []
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
const MAP := Rect2(28,250,664,380)

func setup(data: CountryCatalog, typeface: FontVariation) -> void:
	catalog = data
	font = typeface
	size = Vector2(720,1280)
	var name_edit := LineEdit.new()
	name_edit.position = Vector2(28,170)
	name_edit.size = Vector2(430,54)
	name_edit.text = campaign.player_name
	name_edit.max_length = 16
	add_child(name_edit)
	button("SAVE NAME",Rect2(474,170,218,54),func() -> void:
		message = "Name saved" if campaign.set_name(name_edit.text) else "Enter 1–16 characters."
		name_edit.text = campaign.player_name)
	continent = OptionButton.new()
	continent.position = Vector2(28,650)
	continent.size = Vector2(265,54)
	for value in ["All continents","Africa","Asia","Europe","North America","South America","Oceania","Seven seas (open ocean)"]: continent.add_item(value)
	continent.item_selected.connect(func(_i: int) -> void: refresh())
	add_child(continent)
	search = LineEdit.new()
	search.position = Vector2(308,650)
	search.size = Vector2(384,54)
	search.placeholder_text = "Search country"
	search.text_changed.connect(func(_s: String) -> void: refresh())
	add_child(search)
	list = ItemList.new()
	list.position = Vector2(28,720)
	list.size = Vector2(664,245)
	list.add_theme_font_override("font",font)
	list.add_theme_font_size_override("font_size",21)
	list.item_selected.connect(func(i: int) -> void: select(listed[i]))
	add_child(list)
	for i in 3:
		var value: int = i
		difficulties.append(button(["EASY · 3","MEDIUM · 5","HARD · 7"][i],Rect2(28+i*226,1050,212,48),func() -> void: difficulty(value)))
	play_button = button("PLAY",Rect2(28,1115,664,77),func() -> void: play_requested.emit())
	bonus_button = button("DEMO · CLAIM +225",Rect2(350,968,342,52),func() -> void: bonus_requested.emit(selected.country_id))
	button("+",Rect2(624,270,48,48),func() -> void: zoom = minf(5,zoom*1.3))
	button("−",Rect2(624,328,48,48),func() -> void: zoom = maxf(1,zoom/1.3); pan = pan.limit_length(500*(zoom-1)))
	difficulty(0)
	var initial := "bgd"
	if not campaign.starting.is_empty(): initial = campaign.starting
	if not campaign.conquered.is_empty():
		for country in catalog.maps:
			if campaign.can_attack(country.country_id,catalog):
				initial = country.country_id
				break
	select(initial)

func difficulty(value: int) -> void:
	for i in difficulties.size(): difficulties[i].add_theme_stylebox_override("normal",box(Color("884ddd") if i == value else Color("14546f")))
	difficulty_changed.emit(value)

func refresh() -> void:
	list.clear()
	listed.clear()
	for country in catalog.maps:
		if continent.selected > 0 and country.continent != continent.get_item_text(continent.selected): continue
		if not search.text.is_empty() and not country.display_name.to_lower().contains(search.text.to_lower()): continue
		var owned := campaign.conquered.has(country.country_id)
		var available := campaign.can_attack(country.country_id,catalog)
		list.add_item(("✓ " if owned else "→ " if available else "· ")+country.display_name)
		list.set_item_custom_fg_color(list.item_count-1,Color("d0aaff") if owned else Color("a4ffcf") if available else Color("88a9b9"))
		listed.append(country.country_id)

func select(id: String) -> void:
	var country := catalog.find(id)
	if country == null: return
	selected = country
	country_selected.emit(id)
	refresh()
	play_button.disabled = not campaign.can_attack(id,catalog)
	bonus_button.visible = wallet != null and wallet.claimed("country:"+id) and not wallet.claimed("bonus:"+id)
	play_button.text = "CONQUERED" if campaign.conquered.has(id) else "PLAY · "+country.display_name if not play_button.disabled else "LOCKED · CONQUER A NEIGHBOR"
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
	var base := Vector2((p.x+180)/360*MAP.size.x,(85-clampf(p.y,-60,85))/145*MAP.size.y)
	return MAP.get_center()+(base-MAP.size*0.5)*zoom+pan

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if not MAP.has_point(event.position): return
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed: zoom = clampf(zoom*(1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1/1.2),1,5)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if event.pressed: distance = 0
			elif distance < 10: pick(event.position)
	elif event is InputEventMouseMotion and dragging:
		pan += event.relative
		distance += event.relative.length()
	elif event is InputEventScreenTouch:
		if event.pressed and MAP.has_point(event.position):
			fingers[event.index] = event.position
			distance = 0
		else:
			if fingers.has(event.index) and fingers.size() == 1 and distance < 10: pick(event.position)
			fingers.erase(event.index)
		pinch = 0
	elif event is InputEventScreenDrag and fingers.has(event.index):
		var old: Vector2 = fingers[event.index]
		fingers[event.index] = event.position
		distance += old.distance_to(event.position)
		if fingers.size() == 1: pan += event.position-old
		else:
			var values := fingers.values()
			var length: float = values[0].distance_to(values[1])
			if pinch > 0: zoom = clampf(zoom*length/pinch,1,5)
			pinch = length
	pan = pan.clamp(-MAP.size*(zoom-1)*0.5,MAP.size*(zoom-1)*0.5)
	accept_event()

func pick(point: Vector2) -> void:
	for country in catalog.maps:
		for ring in country.map_rings:
			var polygon := PackedVector2Array()
			for p in ring: polygon.append(world_point(Vector2(p[0],p[1])))
			if Geometry2D.is_point_in_polygon(point,polygon):
				select(country.country_id)
				return

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
	if selected != null:
		for id in selected.sea_neighbors:
			var neighbor := catalog.find(id)
			if neighbor == null: continue
			var a := world_point(Vector2(selected.longitude,selected.latitude))
			var b := world_point(Vector2(neighbor.longitude,neighbor.latitude))
			if not MAP.has_point(a) or not MAP.has_point(b): continue
			for i in 12: draw_circle(a.lerp(b,float(i)/12),2+sin(pulse*3-i)*0.5,Color("ffe6a0"))
		text(selected.display_name.left(34),Vector2(30,1000),26,Color("ffe49a"))
	text(message.left(80),Vector2(30,1030),14,Color("cfece9"))
	text("DRAG TO EXPLORE · PINCH TO ZOOM",Vector2(30,619),13)
	text("Conquer neighbors. Follow sea routes. Rule the world.",Vector2(30,1230),17,Color("c8efed"))
