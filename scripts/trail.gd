class_name ConquerTrail
extends Node2D

var points := PackedVector2Array()
var departure := PackedVector2Array()
var tint: Color = Color.CYAN
var age: float = 0.0

func clear() -> void:
	points.clear()
	departure.clear()
	queue_redraw()

func append_point(point: Vector2) -> void:
	points.append(point)
	queue_redraw()

func hits(a: Vector2, b: Vector2, radius: float, skip_tail: int = 0) -> bool:
	for i in maxi(0, points.size() - 1 - skip_tail):
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
	if not points.is_empty():
		age += delta
		queue_redraw()

func _draw() -> void:
	if points.size() < 2:
		return
	var glow := Color(tint, 0.10 + sin(age * 3.0) * 0.025)
	draw_polyline(points, glow, 26.0, true)
	draw_polyline(points, Color(tint.lightened(0.4), 0.35), 15.0, true)
	draw_polyline(points, tint.lightened(0.65), 7.5, true)
	draw_polyline(points, Color(1, 1, 1, 0.86), 2.5, true)
	for p in points:
		draw_circle(p, 3.6, tint.lightened(0.65))
