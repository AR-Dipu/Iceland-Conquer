class_name CountryBanner
extends Control
var country: CountryMap
var title := Label.new()
var subtitle := Label.new()
var silhouette := PackedVector2Array()
var silhouette_mesh: ArrayMesh
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = ConquestTheme.get_theme()
	title.add_theme_font_size_override("font_size",32)
	title.add_theme_font_override("font",ConquestTheme.heading_font())
	title.add_theme_color_override("font_color",ConquestTheme.GOLD)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle.add_theme_font_size_override("font_size",16)
	subtitle.add_theme_color_override("font_color",ConquestTheme.MUTED)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	add_child(subtitle)
	resized.connect(_layout)
func set_country(value: CountryMap, detail: String = "COUNTRY CONQUEST") -> void:
	country = value
	title.text = value.display_name.to_upper() if value != null else "CHOOSE YOUR COUNTRY"
	subtitle.text = detail
	_layout()
	queue_redraw()
func _layout() -> void:
	title.position = Vector2(92,9)
	title.size = Vector2(maxf(1,size.x-110),size.y-40)
	var font_size: int = 32
	while font_size > 16 and _title_height(font_size) > size.y-40:
		font_size -= 2
	title.add_theme_font_size_override("font_size",font_size)
	title.size = Vector2(maxf(1,size.x-110),size.y-40)
	subtitle.position = Vector2(94,size.y-29)
	subtitle.size.x = maxf(1,size.x-110)
	silhouette.clear()
	silhouette_mesh = null
	if country != null:
		var bounds := IslandGeometry.bounds(country.outline)
		var factor := 54/maxf(bounds.size.x,bounds.size.y)
		for point in country.outline: silhouette.append((point-bounds.get_center())*factor+Vector2(46,size.y*0.5))
		var indices := IslandGeometry.triangles_cached(country.outline)
		if not indices.is_empty(): silhouette_mesh = CountryPresentation._mesh(silhouette,indices)
	queue_redraw()

func _title_height(pixels: int) -> float:
	var width := maxf(1,size.x-110)
	var serif_height := ConquestTheme.heading_font().get_multiline_string_size(title.text,HORIZONTAL_ALIGNMENT_LEFT,width,pixels).y
	var fallback_height := ConquestTheme.get_font().get_multiline_string_size(title.text,HORIZONTAL_ALIGNMENT_LEFT,width,pixels).y
	return maxf(serif_height, fallback_height)
func _draw() -> void:
	draw_style_box(ConquestTheme.panel(Color("343b31"),ConquestTheme.GOLD),Rect2(Vector2.ZERO,size))
	draw_circle(Vector2(46,size.y*0.5),34,Color("505240"))
	if silhouette_mesh != null: draw_mesh(silhouette_mesh,null,Transform2D.IDENTITY,ConquestTheme.GOLD)
