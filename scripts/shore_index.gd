class_name ShoreIndex
extends RefCounted
const CELL: float = 128.0
static var cache: Dictionary = {}
static func data(polygon: PackedVector2Array) -> Dictionary:
	var key := hash(polygon)
	if cache.has(key): return cache[key]
	if cache.size() >= 8: cache.erase(cache.keys()[0])
	var cells: Dictionary = {}
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i+1)%polygon.size()]
		var lo := Vector2i(floori(minf(a.x,b.x)/CELL),floori(minf(a.y,b.y)/CELL))
		var hi := Vector2i(floori(maxf(a.x,b.x)/CELL),floori(maxf(a.y,b.y)/CELL))
		for x in range(lo.x,hi.x+1):
			for y in range(lo.y,hi.y+1):
				var cell := Vector2i(x,y)
				if not cells.has(cell): cells[cell] = []
				cells[cell].append(i)
	cache[key] = {"cells":cells,"bounds":IslandGeometry.bounds(polygon)}
	return cache[key]
static func edges(polygon: PackedVector2Array, a: Vector2, b: Vector2, padding: float = 0.001) -> Array:
	var cells: Dictionary = data(polygon).cells
	var lo := Vector2i(floori((minf(a.x,b.x)-padding)/CELL),floori((minf(a.y,b.y)-padding)/CELL))
	var hi := Vector2i(floori((maxf(a.x,b.x)+padding)/CELL),floori((maxf(a.y,b.y)+padding)/CELL))
	var found: Dictionary = {}
	for x in range(lo.x,hi.x+1):
		for y in range(lo.y,hi.y+1):
			for index in cells.get(Vector2i(x,y),[]): found[index] = true
	var result := found.keys()
	result.sort()
	return result
static func nearest(polygon: PackedVector2Array, point: Vector2) -> Dictionary:
	var radius: float = CELL
	var candidates: Array = []
	while candidates.is_empty() and radius < 8192:
		candidates = edges(polygon,point,point,radius)
		radius *= 2
	if candidates.is_empty(): return IslandGeometry.nearest(polygon,point)
	var best: float = INF
	var answer := {"point":point,"edge":0}
	for i in candidates:
		var p := Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()])
		if point.distance_squared_to(p) < best:
			best = point.distance_squared_to(p)
			answer = {"point":p,"edge":i}
	# Once a candidate exists, cover the entire best-distance square. An edge
	# outside it cannot be closer, including in concave bays.
	for i in edges(polygon,point,point,sqrt(best)+0.001):
		var p := Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()])
		if point.distance_squared_to(p) < best:
			best = point.distance_squared_to(p)
			answer = {"point":p,"edge":i}
	return answer

static func segment_inside(polygon: PackedVector2Array, a: Vector2,b: Vector2) -> bool:
	if not Geometry2D.is_point_in_polygon(a,polygon) or not Geometry2D.is_point_in_polygon(b,polygon): return false
	var cuts: Array[float] = [0,1]
	var length := a.distance_to(b)
	if length < 0.001: return true
	for i in edges(polygon,a,b):
		var hit: Variant = Geometry2D.segment_intersects_segment(a,b,polygon[i],polygon[(i+1)%polygon.size()])
		if hit != null: cuts.append(clampf(a.distance_to(hit)/length,0,1))
	cuts.sort()
	for i in cuts.size()-1:
		if cuts[i+1]-cuts[i] > 0.00001 and not Geometry2D.is_point_in_polygon(a.lerp(b,(cuts[i]+cuts[i+1])*0.5),polygon): return false
	return true

static func reach(polygon: PackedVector2Array, start: Vector2, direction: Vector2, maximum: float = 700) -> float:
	var finish := start+direction*maximum
	var result: float = maximum
	for i in edges(polygon,start,finish):
		var hit: Variant = Geometry2D.segment_intersects_segment(start,finish,polygon[i],polygon[(i+1)%polygon.size()])
		if hit != null: result = minf(result,start.distance_to(hit))
	return result
