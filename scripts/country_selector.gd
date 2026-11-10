class_name CountrySelector
extends Control
signal country_selected(country_id: String)
signal difficulty_changed(value: int)
signal play_requested
var catalog: CountryCatalog
var selected: CountryMap
var font: FontVariation
var message: String = ""
var buttons: Dictionary = {}
var play_button: Button
var mascot: Texture2D = preload("res://assets/characters/purple_player.png")
const PIN_LABELS = {"bgd": Vector2(544, 300), "ind": Vector2(405, 449), "lka": Vector2(570, 512), "jpn": Vector2(613, 406), "isl": Vector2(295, 299)}
const COORDS = {"bgd": Vector2(90.3, 23.7), "ind": Vector2(78.9, 23.2), "lka": Vector2(80.7, 7.9), "jpn": Vector2(138, 36), "isl": Vector2(-19, 65)}

func setup(data: CountryCatalog, typeface: FontVariation) -> void:
	catalog = data
	font = typeface
	selected = catalog.maps[0]
	size = Vector2(720, 1280)
	mouse_filter = MOUSE_FILTER_STOP
	for i in catalog.maps.size():
		var country: CountryMap = catalog.maps[i]
		var rect := Rect2(28 + (i % 2) * 342, 618 + (i / 2) * 74, 322, 60)
		var button := make_button(country.display_name, rect, func() -> void: select(country.country_id))
		buttons[country.country_id] = button
		var label_pos: Vector2 = PIN_LABELS[country.country_id]
		var pin := make_button(country.display_name, Rect2(label_pos - Vector2(48, 18), Vector2(96, 36)), func() -> void: select(country.country_id))
		pin.add_theme_font_size_override("font_size", 13)
	play_button = make_button("PLAY", Rect2(28, 1127, 664, 80), func() -> void: play_requested.emit())
	play_button.add_theme_font_size_override("font_size", 34)
	play_button.add_theme_stylebox_override("normal", box(Color("9555ef"), Color("d9baff")))
	play_button.add_theme_stylebox_override("hover", box(Color("ad76ff"), Color.WHITE))
	for i in 3:
		var value: int = i
		var button := make_button(["EASY / 3 BOTS","MEDIUM / 5 BOTS","HARD / 7 BOTS"][i], Rect2(28+i*226,1081,212,38), func() -> void: difficulty_changed.emit(value))
		button.add_theme_font_size_override("font_size",15)
	select(selected.country_id)

func box(color: Color, edge: Color = Color("438ba0")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	style.shadow_size = 5
	style.shadow_color = Color(0, 0.1, 0.2, 0.16)
	style.shadow_offset = Vector2(0, 4)
	return style

func make_button(label: String, rect: Rect2, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color("f2fcff"))
	button.add_theme_stylebox_override("normal", box(Color("095776")))
	button.add_theme_stylebox_override("hover", box(Color("146b88")))
	button.add_theme_stylebox_override("pressed", box(Color("57328f"), Color("c6a4ff")))
	button.pressed.connect(action)
	add_child(button)
	return button

func select(country_id: String) -> void:
	var choice: CountryMap = catalog.find(country_id)
	if choice == null:
		return
	selected = choice
	for id in buttons:
		buttons[id].add_theme_stylebox_override("normal", box(Color("8050ce") if id == country_id else Color("095776"), Color("d3b2ff") if id == country_id else Color("438ba0")))
	country_selected.emit(country_id)
	queue_redraw()

func text(value: String, point: Vector2, pixels: int, tint: Color = Color("edfcff"), centered: bool = false) -> void:
	if centered:
		point.x -= font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x * 0.5
	draw_string(font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, tint)

func world_point(lon_lat: Vector2) -> Vector2:
	return Vector2(48 + (lon_lat.x + 180) / 360 * 624, 278 + (85 - lon_lat.y) / 145 * 276)

func preview_transform(country: CountryMap, rect: Rect2) -> Transform2D:
	var factor: float = minf(rect.size.x / country.land_bounds.size.x, rect.size.y / country.land_bounds.size.y)
	return Transform2D(0, Vector2.ONE * factor, 0, rect.get_center() - country.land_bounds.get_center() * factor)

func _draw() -> void:
	if catalog == null:
		return
	text("Y O U R   N E X T   A D V E N T U R E", Vector2(32, 43), 15, Color("a8f3e9"))
	text("ISLAND", Vector2(28, 105), 53, Color("ffe28a"))
	text("CONQUER", Vector2(28, 163), 53)
	text("Pick a country. Make it your island.", Vector2(31, 197), 20, Color("bdf3f6"))
	draw_texture_rect(mascot, Rect2(508, 48, 155, 155), false)
	draw_style_box(box(Color(0.015, 0.23, 0.34, 0.94)), Rect2(28, 227, 664, 355))
	text("CHOOSE YOUR ISLAND", Vector2(49, 260), 18, Color("f7e8b0"))
	text("5 COUNTRIES UNLOCKED", Vector2(465, 260), 13, Color("a8e6e8"))
	for line in range(1, 5):
		var y: float = 280 + line * 54
		draw_line(Vector2(49, y), Vector2(671, y), Color(0.6, 0.9, 1, 0.06), 1)
	for raw_ring in catalog.world:
		var polygon := PackedVector2Array()
		for p in raw_ring:
			polygon.append(world_point(Vector2(p[0], clampf(p[1], -60, 85))))
		if polygon.size() >= 3 and not Geometry2D.triangulate_polygon(polygon).is_empty():
			draw_colored_polygon(polygon, Color("357c8d"))
	for id in COORDS:
		var p: Vector2 = world_point(COORDS[id])
		var label: Vector2 = PIN_LABELS[id]
		draw_line(p, label, Color("b9e6dc"), 1.5, true)
		draw_circle(p, 7.5, Color("c99bff") if id == selected.country_id else Color("ffe39a"))
		draw_circle(p, 3, Color.WHITE)
	text("FIVE COUNTRIES. ONE CROWN.", Vector2(31, 608), 15, Color("cef5ef"))
	text("ALL ISLANDS", Vector2(530, 791), 19, Color("ffe28a"), true)
	text("READY TO EXPLORE", Vector2(530, 813), 13, Color("c1ecee"), true)
	draw_style_box(box(Color("07516c")), Rect2(28, 860, 664, 216))
	var transform: Transform2D = preview_transform(selected, Rect2(49, 883, 185, 168))
	var polygon: PackedVector2Array = transform * selected.outline
	var border: PackedVector2Array = polygon.duplicate()
	border.append(border[0])
	draw_colored_polygon(polygon, Color("b7df70"))
	draw_polyline(border, Color("ffe5a4"), 6, true)
	text(selected.display_name.to_upper(), Vector2(262, 905), 29, Color("ffe6a1"))
	text("YOUR NEXT CONQUEST", Vector2(263, 935), 14, Color("c8a9ff"))
	text("Honshu + offshore scenery" if selected.country_id == "jpn" else "A country-shaped tropical island", Vector2(263, 974), 17)
	text("Bigger world. Smooth camera.", Vector2(263, 1005), 17, Color("c5f1ef"))
	text("Purple is you. Reach 100% to win.", Vector2(263, 1036), 17, Color("dac7ff"))
	if not message.is_empty():
		text(message, Vector2(360, 1108), 23, Color("ffe4a0"), true)
	text("TOUCH ANYWHERE, DRAG TO STEER  /  RELEASE TO STOP", Vector2(360, 1250), 15, Color("c5f3f2"), true)
