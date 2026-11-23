class_name WorldCampaignSelector
extends Control
signal country_selected(country_id: String)
signal difficulty_changed(value: int)
signal play_requested
signal bonus_requested(country_id: String)
var catalog: CountryCatalog
var campaign: CampaignProgress
var wallet: PracticeWallet
const Collection = preload("res://scripts/character_collection.gd")
var collection: Collection
var shop: Panel
var shop_status: Label
var shop_actions: Dictionary = {}
var shop_portraits: Array[TextureRect] = []
var shop_clock := 0.0
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
var country_banner: CountryBanner
var route_layer: Node2D
const MAP := Rect2(28,328,664,464)

func setup(data: CountryCatalog, typeface: FontVariation) -> void:
	catalog = data
	theme = ConquestTheme.get_theme()
	font = typeface
	size = Vector2(720,1280)
	name_edit = LineEdit.new()
	name_edit.position = Vector2(28,172)
	name_edit.size = Vector2(322,136)
	name_edit.text = campaign.player_name
	name_edit.max_length = 16
	add_child(name_edit)
	save_button = button("SAVE",Rect2(368,172,144,136),save_name)
	cancel_button = button("CANCEL",Rect2(526,172,166,136),cancel_name)
	name_edit.text_submitted.connect(func(_value: String) -> void: save_name())
	name_display = Label.new()
	name_display.position = Vector2(46,207)
	name_display.size = Vector2(530,54)
	name_display.add_theme_font_override("font",font)
	name_display.add_theme_font_size_override("font_size",27)
	add_child(name_display)
	edit_button = button("",Rect2(556,172,136,136),begin_name_edit)
	edit_button.tooltip_text = "Edit name"
	edit_button.draw.connect(func() -> void:
		edit_button.draw_line(Vector2(30,65),Vector2(62,33),Color("fff0bc"),5,true)
		edit_button.draw_line(Vector2(27,69),Vector2(39,66),Color("fff0bc"),2,true))
	set_name_mode(not campaign.name_saved)
	if FileAccess.file_exists("res://assets/maps/continent_borders.json"):
		continent_borders = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/continent_borders.json"))
	for i in 3:
		var value: int = i
		difficulties.append(button(["EASY · 3","MEDIUM · 5","HARD · 7"][i],Rect2(28+i*226,936,212,136),func() -> void: difficulty(value)))
	play_button = button("START CONQUEST",Rect2(28,1080,664,136),func() -> void:
		if can_play(): play_requested.emit())
	bonus_button = button("DEMO · CLAIM +225",Rect2(292,648,380,136),func() -> void: bonus_requested.emit(selected.country_id))
	button("CHARACTERS",Rect2(435,4,257,136),open_shop)
	route_layer = Node2D.new()
	route_layer.material = ShaderMaterial.new()
	route_layer.material.shader = preload("res://assets/shaders/trail_glow.gdshader")
	route_layer.draw.connect(_draw_routes)
	add_child(route_layer)
	country_banner = CountryBanner.new()
	country_banner.position = Vector2(28,808)
	country_banner.size = Vector2(664,112)
	add_child(country_banner)
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
	_build_shop()

func _build_shop() -> void:
	shop = Panel.new()
	shop.size = size
	shop.add_theme_stylebox_override("panel", ConquestTheme.panel(ConquestTheme.INK, ConquestTheme.GOLD))
	add_child(shop)
	_shop_label("Characters", Vector2(34,32), 44).add_theme_font_override("font",ConquestTheme.heading_font())
	shop_status = _shop_label("", Vector2(34,96), 24)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24,152)
	scroll.size = Vector2(672,938)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shop.add_child(scroll)
	var list := Control.new()
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	list.custom_minimum_size = Vector2(648,Collection.CATALOG.size()*214)
	scroll.add_child(list)
	var row := 0
	for id in Collection.CATALOG:
		var entry: Array = Collection.CATALOG[id]
		var y := row * 214
		var card := Panel.new()
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.position = Vector2(0,y)
		card.size = Vector2(648,204)
		card.add_theme_stylebox_override("panel", ConquestTheme.panel())
		list.add_child(card)
		var portrait := TextureRect.new()
		portrait.texture = Collection.artwork(id)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.position = Vector2(16,33)
		portrait.size = Vector2(125,125)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(portrait)
		shop_portraits.append(portrait)
		_shop_label(entry[0], Vector2(150,20), 29,card)
		_shop_label(entry[2] + "\n" + entry[3], Vector2(150,68), 21,card)
		var action := Button.new()
		action.position = Vector2(434,38)
		action.size = Vector2(198,136)
		ConquestTheme.style_button(action,true)
		action.pressed.connect(func() -> void: _shop_action(id))
		card.add_child(action)
		shop_actions[id] = action
		row += 1
	var close := Button.new()
	close.text = "WORLD MAP"
	close.position = Vector2(24,1110)
	close.size = Vector2(672,128)
	ConquestTheme.style_button(close)
	close.pressed.connect(func() -> void: shop.hide())
	shop.add_child(close)
	shop.hide()

func _shop_label(value: String, at: Vector2, pixels: int, parent: Control = null) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size", pixels)
	(parent if parent != null else shop).add_child(label)
	return label

func open_shop() -> void:
	fingers.clear()
	dragging = false
	multitouch = false
	name_edit.release_focus()
	shop.show()
	_refresh_shop()

func _refresh_shop(message_text: String = "") -> void:
	shop_status.text = message_text if not message_text.is_empty() else "Scroll to browse"
	for id in shop_actions:
		var action: Button = shop_actions[id]
		action.disabled = id == collection.equipped
		action.text = "EQUIPPED" if action.disabled else "EQUIP" if collection.owns(id) else "BUY\n%d COINS" % Collection.CATALOG[id][1]

func _shop_action(id: String) -> void:
	if collection.owns(id):
		_refresh_shop("Character equipped" if collection.equip(id) else "Could not save equipment")
	elif wallet.balance < Collection.CATALOG[id][1]:
		_refresh_shop("Need %d more coins" % (Collection.CATALOG[id][1] - wallet.balance))
	elif collection.buy(id):
		_refresh_shop("Unlocked · Equip to play")
	else:
		_refresh_shop("Purchase could not be saved")

func can_play() -> bool:
	return selected != null and campaign.can_play(selected.country_id,catalog) and (not campaign.starting.is_empty() or not campaign.conquered.is_empty() or first_choice_made)

func difficulty(value: int) -> void:
	for i in difficulties.size(): difficulties[i].add_theme_stylebox_override("normal",ConquestTheme.panel(ConquestTheme.PURPLE if i == value else ConquestTheme.PANEL,ConquestTheme.GOLD if i == value else Color("45617e")))
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
	queue_redraw()
	if route_layer != null: route_layer.queue_redraw()

func select(id: String) -> void:
	var country := catalog.find(id)
	if country == null: return
	selected = country
	country_banner.set_country(country,"COUNTRY CONQUEST · CLAIM YOUR LEGACY")
	queue_redraw()
	route_layer.queue_redraw()
	country_selected.emit(id)
	play_button.disabled = not can_play()
	bonus_button.visible = wallet != null and wallet.claimed("country:"+id) and not wallet.claimed("bonus:"+id)
	play_button.text = "REPLAY CONQUEST" if campaign.conquered.has(id) else "START CONQUEST" if not play_button.disabled else "LOCKED · CONQUER A NEIGHBOR"
	if campaign.starting.is_empty() and campaign.conquered.is_empty(): play_button.text = "CONFIRM CONQUEST" if first_choice_made else "CHOOSE YOUR COUNTRY ON THE MAP"
	message = ""
	if play_button.disabled and not campaign.conquered.has(id):
		var names: Array[String] = []
		for n in country.neighbors:
			var neighbor := catalog.find(n)
			if neighbor != null: names.append(neighbor.display_name)
		message = "Connected to: " + ", ".join(names.slice(0,4))

func box(color: Color) -> StyleBoxFlat:
	return ConquestTheme.panel(color)

func button(label: String, rect: Rect2, action: Callable) -> Button:
	var control := Button.new()
	control.text = label
	control.position = rect.position
	control.size = rect.size
	ConquestTheme.style_button(control,label.begins_with("START") or label == "SAVE" or label.begins_with("DEMO"))
	control.pressed.connect(action)
	add_child(control)
	return control

func _process(delta: float) -> void:
	pulse += delta
	if shop != null and shop.visible:
		shop_clock += delta
		for i in shop_portraits.size():
			var portrait := shop_portraits[i]
			portrait.position.y = 33.0 + sin(shop_clock*3.8+i*0.8)*4.0

func world_point(p: Vector2) -> Vector2:
	# Mercator projection keeps country shapes recognizable in the taller map.
	var latitude: float = clampf(p.y,-60,85)
	var mercator: float = log(tan(PI*0.25+deg_to_rad(latitude)*0.5))
	var base := Vector2(p.x/360*MAP.size.x,-mercator*MAP.size.x/TAU)
	return MAP.get_center()+base*zoom+pan

func _gui_input(event: InputEvent) -> void:
	queue_redraw()
	if route_layer != null: route_layer.queue_redraw()
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
	draw_string(ConquestTheme.heading_font(),Vector2(28,77),"Country Conquer",HORIZONTAL_ALIGNMENT_LEFT,-1,38,ConquestTheme.INK)
	text("WORLD CAMPAIGN · %d / %d CONQUERED" % [campaign.conquered.size(),catalog.maps.size()],Vector2(30,115),18,ConquestTheme.INK)
	draw_style_box(ConquestTheme.panel(),Rect2(28,132,664,180))
	if wallet != null: text("%d COINS" % wallet.balance,Vector2(510,168),17,Color("ffe49a"))
	text("YOUR NAME",Vector2(46,160),13,Color("cbb5ff"))
	draw_style_box(box(Color("384e50")),MAP)
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
		var color := Color("9b5cff") if owned else Color("b0b885") if available else Color("777d68")
		if country == selected: color = ConquestTheme.GOLD
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
	text(message.left(80),Vector2(30,930),14,Color("cfece9"))
	text("TAP A COUNTRY · DRAG / PINCH TO EXPLORE",Vector2(42,779),13)
	text("CONQUER COUNTRIES. RULE THE WORLD.",Vector2(30,1248),17,ConquestTheme.INK)


func _draw_routes() -> void:
	if selected == null: return
	for id in selected.sea_neighbors:
		var neighbor := catalog.find(id)
		if neighbor == null: continue
		var a := world_point(Vector2(selected.longitude,selected.latitude))
		var b := world_point(Vector2(neighbor.longitude,neighbor.latitude))
		if not MAP.has_point(a) or not MAP.has_point(b): continue
		for i in 12: route_layer.draw_circle(a.lerp(b,float(i)/12),2.2,ConquestTheme.GOLD)
