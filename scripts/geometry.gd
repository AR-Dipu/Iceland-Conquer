class_name IslandGeometry
extends RefCounted
## Continuous polygon helpers. Clockwise contours in Godot booleans are holes.

static func area(poly: PackedVector2Array) -> float:
	var result: float = 0.0
	for i in poly.size():
		result += poly[i].cross(poly[(i + 1) % poly.size()])
	return absf(result) * 0.5

static func blob(center: Vector2, radius: Vector2, phase: float = 0.0, count: int = 96) -> PackedVector2Array:
	var poly := PackedVector2Array()
	for i in count:
		var a: float = TAU * float(i) / count
		var wobble: float = 1.0 + 0.065 * sin(a * 3.0 + phase) + 0.035 * cos(a * 5.0 - phase)
		poly.append(center + Vector2(cos(a), sin(a)) * radius * wobble)
	return poly

static func contains(polys: Array[PackedVector2Array], point: Vector2) -> bool:
	for poly in polys:
		if Geometry2D.is_point_in_polygon(point, poly):
			return true
	return false

static func nearest(poly: PackedVector2Array, point: Vector2) -> Dictionary:
	var best: float = INF
	var result: Dictionary = {"point": point, "edge": 0}
	for i in poly.size():
		var p := Geometry2D.get_closest_point_to_segment(point, poly[i], poly[(i + 1) % poly.size()])
		var d: float = p.distance_squared_to(point)
		if d < best:
			best = d
			result = {"point": p, "edge": i}
	return result

static func simple(poly: PackedVector2Array) -> bool:
	if poly.size() < 3 or area(poly) < 8.0:
		return false
	return not Geometry2D.triangulate_polygon(poly).is_empty()

static func subtract(subject: PackedVector2Array, cutter: PackedVector2Array, depth: int = 0) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = Geometry2D.clip_polygons(subject, cutter)
	var hole := PackedVector2Array()
	for p in result:
		if Geometry2D.is_polygon_clockwise(p):
			hole = p
			break
	if hole.is_empty():
		return result.filter(func(p: PackedVector2Array) -> bool: return area(p) > 2.0)
	# Polygon2D has no holes. Split the subject through the hole, then subtract
	# from each half. This preserves the empty space as simple renderable pieces.
	assert(depth < 12, "Polygon hole split did not converge")
	var cut_y: float = 0.0
	for p in hole:
		cut_y += p.y
	cut_y /= hole.size()
	var upper := PackedVector2Array([Vector2(-10000, -10000), Vector2(10000, -10000), Vector2(10000, cut_y), Vector2(-10000, cut_y)])
	var lower := PackedVector2Array([Vector2(-10000, cut_y), Vector2(10000, cut_y), Vector2(10000, 10000), Vector2(-10000, 10000)])
	var pieces: Array[PackedVector2Array] = []
	for half in [upper, lower]:
		for p in Geometry2D.intersect_polygons(subject, half):
			pieces.append_array(subtract(p, cutter, depth + 1))
	return pieces

static func merge_regions(polys: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = polys.duplicate()
	var changed := true
	while changed:
		changed = false
		for i in result.size():
			for j in range(i + 1, result.size()):
				var merged: Array[PackedVector2Array] = Geometry2D.merge_polygons(result[i], result[j])
				if merged.size() == 1 and not Geometry2D.is_polygon_clockwise(merged[0]):
					result[i] = merged[0]
					result.remove_at(j)
					changed = true
					break
			if changed:
				break
	return result

static func boundary_capture(poly: PackedVector2Array, trail: PackedVector2Array) -> PackedVector2Array:
	if trail.size() < 4:
		return PackedVector2Array()
	var start: Dictionary = nearest(poly, trail[0])
	var finish: Dictionary = nearest(poly, trail[-1])
	var candidates: Array[PackedVector2Array] = []
	for direction in [1, -1]:
		var candidate := PackedVector2Array([start.point])
		for i in range(1, trail.size() - 1):
			candidate.append(trail[i])
		candidate.append(finish.point)
		var edge: int = int(finish.edge)
		var target: int = int(start.edge)
		if direction == 1:
			var index: int = (edge + 1) % poly.size()
			var stop: int = (target + 1) % poly.size()
			while index != stop:
				candidate.append(poly[index])
				index = (index + 1) % poly.size()
		else:
			var index: int = edge
			var stop: int = target
			while index != stop:
				candidate.append(poly[index])
				index = (index - 1 + poly.size()) % poly.size()
		if simple(candidate):
			candidates.append(candidate)
	if candidates.is_empty():
		return PackedVector2Array()
	candidates.sort_custom(func(a: PackedVector2Array, b: PackedVector2Array) -> bool: return area(a) < area(b))
	return candidates[0]

static func segment_distance(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
		return 0.0
	return minf(minf(a.distance_to(Geometry2D.get_closest_point_to_segment(a, c, d)), b.distance_to(Geometry2D.get_closest_point_to_segment(b, c, d))), minf(c.distance_to(Geometry2D.get_closest_point_to_segment(c, a, b)), d.distance_to(Geometry2D.get_closest_point_to_segment(d, a, b))))

static func soften(poly: PackedVector2Array, radius: float = 11.0) -> PackedVector2Array:
	# Round only pronounced corners; retain smooth sampled coastlines. Removing
	# near-collinear points first prevents unbounded vertex growth across captures.
	var clean := PackedVector2Array()
	for i in poly.size():
		var a: Vector2 = poly[(i - 1 + poly.size()) % poly.size()]
		var b: Vector2 = poly[i]
		var c: Vector2 = poly[(i + 1) % poly.size()]
		if b.distance_to(Geometry2D.get_closest_point_to_segment(b, a, c)) > 0.28:
			clean.append(b)
	if clean.size() < 3:
		return poly
	var result := PackedVector2Array()
	for i in clean.size():
		var a: Vector2 = clean[(i - 1 + clean.size()) % clean.size()]
		var b: Vector2 = clean[i]
		var c: Vector2 = clean[(i + 1) % clean.size()]
		var incoming: Vector2 = a.direction_to(b)
		var outgoing: Vector2 = b.direction_to(c)
		if incoming.dot(outgoing) > 0.96:
			result.append(b)
			continue
		var trim: float = minf(radius, minf(a.distance_to(b), c.distance_to(b)) * 0.35)
		var begin: Vector2 = b - incoming * trim
		var end: Vector2 = b + outgoing * trim
		for step in 5:
			var t: float = float(step) / 4.0
			result.append(begin.lerp(b, t).lerp(b.lerp(end, t), t))
	return result if simple(result) else poly

static func bounds(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():
		return Rect2()
	var rect := Rect2(poly[0], Vector2.ZERO)
	for point in poly:
		rect = rect.expand(point)
	return rect

static func interior_point(poly: PackedVector2Array) -> Vector2:
	var indices := Geometry2D.triangulate_polygon(poly)
	var best: float = -1
	var point := Vector2.ZERO
	for i in range(0, indices.size(), 3):
		var tri := PackedVector2Array([poly[indices[i]], poly[indices[i + 1]], poly[indices[i + 2]]])
		if area(tri) > best:
			best = area(tri)
			point = (tri[0] + tri[1] + tri[2]) / 3.0
	return point

static func clamp_inside(poly: PackedVector2Array, target: Vector2) -> Vector2:
	if Geometry2D.is_point_in_polygon(target, poly):
		return target
	var near: Dictionary = nearest(poly, target)
	if Geometry2D.is_point_in_polygon(near.point, poly):
		return near.point
	var edge: int = near.edge
	var normal: Vector2 = poly[edge].direction_to(poly[(edge + 1) % poly.size()]).orthogonal()
	for offset in [0.8, -0.8, 2.0, -2.0]:
		var p: Vector2 = near.point + normal * offset
		if Geometry2D.is_point_in_polygon(p, poly):
			return p
	return interior_point(poly)

static func segment_inside(poly: PackedVector2Array, a: Vector2, b: Vector2) -> bool:
	var steps: int = maxi(2, ceili(a.distance_to(b) / 12.0))
	for i in range(steps + 1):
		if not Geometry2D.is_point_in_polygon(a.lerp(b, float(i) / steps), poly):
			return false
	return true
