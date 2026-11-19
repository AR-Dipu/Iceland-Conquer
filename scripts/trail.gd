class_name ConquerTrail
extends Node2D

var points := PackedVector2Array():
	set(value):
		points = value
		stroke_dirty = true
		indexed_count = 0
var departure := PackedVector2Array()
var tint: Color = Color.CYAN
var age: float = 0.0
var stroke_dirty: bool = true
var strokes: Array[Line2D] = []
var cells: Dictionary = {}
var indexed_count: int = 0
var stroke_tint := Color.TRANSPARENT

func near_segments(point: Vector2, radius: float) -> Array:
	return query_segments(point,point,radius)

func query_segments(a: Vector2,b: Vector2,radius: float) -> Array:
	if indexed_count != points.size():
		cells.clear()
		for i in maxi(0,points.size()-1): _index_segment(i)
		indexed_count = points.size()
	var found: Dictionary = {}
	var lo := Vector2i(floori((minf(a.x,b.x)-radius)/64),floori((minf(a.y,b.y)-radius)/64))
	var hi := Vector2i(floori((maxf(a.x,b.x)+radius)/64),floori((maxf(a.y,b.y)+radius)/64))
	for x in range(lo.x,hi.x+1):
		for y in range(lo.y,hi.y+1):
			for index in cells.get(Vector2i(x,y),[]): found[index] = true
	var result := found.keys()
	result.sort()
	return result

func _index_segment(i: int) -> void:
	var a := points[i]
	var b := points[i+1]
	var lo := Vector2i(floori(minf(a.x,b.x)/64),floori(minf(a.y,b.y)/64))
	var hi := Vector2i(floori(maxf(a.x,b.x)/64),floori(maxf(a.y,b.y)/64))
	for x in range(lo.x,hi.x+1):
		for y in range(lo.y,hi.y+1):
			var key := Vector2i(x,y)
			if not cells.has(key): cells[key] = []
			cells[key].append(i)

func clear() -> void:
	points.clear()
	departure.clear()
	stroke_dirty = true
	cells.clear()
	indexed_count = 0
	for line in strokes: line.points = points

func append_point(point: Vector2) -> void:
	points.append(point)
	stroke_dirty = true
	if indexed_count == points.size()-1:
		if points.size() >= 2: _index_segment(points.size()-2)
		indexed_count = points.size()

func hits(a: Vector2, b: Vector2, radius: float, skip_tail: int = 0) -> bool:
	for i in query_segments(a,b,radius):
		if i >= points.size()-1-skip_tail: continue
		if IslandGeometry.segment_distance(a, b, points[i], points[i + 1]) < radius:
			return true
	return false

func self_hit_fraction(a: Vector2, b: Vector2) -> float:
	var earliest: float = INF
	var length: float = a.distance_to(b)
	if length < 0.001:
		return earliest
	for i in maxi(0, points.size() - 2):
		var hit: Variant = Geometry2D.segment_intersects_segment(a, b, points[i], points[i + 1])
		if hit != null and a.distance_to(hit) > 0.01:
			earliest = minf(earliest, a.distance_to(hit) / length)
	return earliest

func _process(delta: float) -> void:
	age += delta
	if stroke_dirty or stroke_tint != tint: _sync_strokes()

func _sync_strokes() -> void:
	var began := WorkMetrics.start()
	if strokes.is_empty():
		for width in [26.0,15.0,7.5,2.5]:
			var line := Line2D.new()
			line.width = width
			line.joint_mode = Line2D.LINE_JOINT_ROUND
			line.begin_cap_mode = Line2D.LINE_CAP_ROUND
			line.end_cap_mode = Line2D.LINE_CAP_ROUND
			line.antialiased = true
			add_child(line)
			strokes.append(line)
		var glow := ShaderMaterial.new()
		glow.shader = preload("res://assets/shaders/trail_glow.gdshader")
		strokes[0].material = glow
	var colors := [Color(tint,0.125),Color(tint.lightened(0.4),0.35),tint.lightened(0.65),Color(1,1,1,0.86)]
	for i in strokes.size():
		strokes[i].points = points
		strokes[i].default_color = colors[i]
	stroke_dirty = false
	stroke_tint = tint
	WorkMetrics.finish("trail_upload",began)
