class_name IslandWorld
extends Node2D
var map: CountryMap
var outline := PackedVector2Array()
var props: Texture2D = preload("res://assets/environment/tropical_props.png")
var clock: float = 0.0
var refresh: float = 0.0

func setup(country: CountryMap) -> void:
	map = country
	outline = map.outline
	z_index = -10
	for prop in map.scenery:
		_add_prop(int(prop.cell), prop.position, float(prop.width))
	queue_redraw()

func _add_prop(cell: int, foot: Vector2, width: float) -> void:
	var sprite := Sprite2D.new()
	var texture := AtlasTexture.new()
	texture.atlas = props
	var size := Vector2(props.get_width(), props.get_height()) / 2.0
	texture.region = Rect2(Vector2(cell % 2, cell / 2) * size, size)
	sprite.texture = texture
	sprite.scale = Vector2.ONE * width / size.x
	sprite.position = foot - Vector2(0, width * 0.44)
	sprite.z_index = 21
	add_child(sprite)

func _process(delta: float) -> void:
	clock += delta
	refresh += delta
	if refresh > 0.08:
		refresh = 0
		queue_redraw()

func _shift(poly: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in poly:
		result.append(p + offset)
	return result

func _ring(poly: PackedVector2Array, width: float, tint: Color) -> void:
	if poly.is_empty():
		return
	var closed := poly.duplicate()
	closed.append(poly[0])
	draw_polyline(closed, tint, width, true)

func _land(poly: PackedVector2Array, decorative: bool = false) -> void:
	var shores: Array[PackedVector2Array] = Geometry2D.offset_polygon(poly, 18, Geometry2D.JOIN_ROUND)
	if shores.is_empty():
		return
	var shore: PackedVector2Array = shores[0]
	_ring(_shift(shore, Vector2(0, 24)), 36, Color(0, 0.23, 0.40, 0.17))
	_ring(_shift(shore, Vector2(0, 17)), 16 + sin(clock * 1.5) * 3, Color(0.62, 1, 1, 0.5))
	draw_colored_polygon(_shift(shore, Vector2(0, 23)), Color("b88d50"))
	draw_colored_polygon(_shift(shore, Vector2(0, 11)), Color("e4ba7c"))
	draw_colored_polygon(shore, Color("ffe3a0"))
	_ring(shore, 3, Color("fff1c4"))
	draw_colored_polygon(poly, Color("b1df68") if not decorative else Color("8ecf65"))
	_ring(poly, 2, Color("d0ed87"))

func _draw() -> void:
	if map == null:
		return
	for ring in map.decorative_islands:
		_land(ring, true)
	_land(outline)
	for i in 180:
		var p := Vector2(fmod(i * 173.7, map.land_bounds.size.x), fmod(i * 271.3, map.land_bounds.size.y))
		if Geometry2D.is_point_in_polygon(p, outline):
			draw_circle(p, 1.8, Color(0.91, 1, 0.62, 0.40))
