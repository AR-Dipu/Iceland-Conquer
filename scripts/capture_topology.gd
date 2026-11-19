class_name CaptureTopology
extends RefCounted
## Planar half-edge faces: ownership boundaries and the excursion form a graph.
## Only bounded faces incident to the trail are eligible; no smaller-side rule.
static func enclosed(owned: Array, trail: PackedVector2Array) -> Dictionary:
	if trail.size() < 2: return {"ok":true,"faces":[]}
	var segments: Array = []
	for polygon in owned:
		for i in polygon.size():
			if polygon[i].distance_to(polygon[(i+1)%polygon.size()]) > 0.002:
				segments.append({"a":polygon[i],"b":polygon[(i+1)%polygon.size()],"trail":false,"cuts":[0.0,1.0]})
	for i in trail.size()-1:
		if trail[i].distance_to(trail[i+1]) > 0.002: segments.append({"a":trail[i],"b":trail[i+1],"trail":true,"cuts":[0.0,1.0]})
	if segments.size() > 6000: return {"ok":false,"faces":[]}
	for i in segments.size():
		var a: Dictionary = segments[i]
		for j in range(i+1,segments.size()):
			var b: Dictionary = segments[j]
			if maxf(a.a.x,a.b.x)+0.001 < minf(b.a.x,b.b.x) or maxf(b.a.x,b.b.x)+0.001 < minf(a.a.x,a.b.x) or maxf(a.a.y,a.b.y)+0.001 < minf(b.a.y,b.b.y) or maxf(b.a.y,b.b.y)+0.001 < minf(a.a.y,a.b.y): continue
			var hit: Variant = Geometry2D.segment_intersects_segment(a.a,a.b,b.a,b.b)
			if hit != null:
				_cut(a,hit)
				_cut(b,hit)
			else:
				for p in [a.a,a.b]:
					if p.distance_to(Geometry2D.get_closest_point_to_segment(p,b.a,b.b)) < 0.001: _cut(b,p)
				for p in [b.a,b.b]:
					if p.distance_to(Geometry2D.get_closest_point_to_segment(p,a.a,a.b)) < 0.001: _cut(a,p)
	var vertices: Array[Vector2] = []
	var ids: Dictionary = {}
	var neighbors: Array = []
	var trail_edges: Dictionary = {}
	for s in segments:
		s.cuts.sort()
		for i in s.cuts.size()-1:
			if s.cuts[i+1]-s.cuts[i] < 0.000001: continue
			var u := _vertex(s.a.lerp(s.b,s.cuts[i]),vertices,ids,neighbors)
			var v := _vertex(s.a.lerp(s.b,s.cuts[i+1]),vertices,ids,neighbors)
			if u == v: continue
			if not neighbors[u].has(v): neighbors[u].append(v)
			if not neighbors[v].has(u): neighbors[v].append(u)
			if s.trail:
				trail_edges[Vector2i(u,v)] = true
				trail_edges[Vector2i(v,u)] = true
	for u in vertices.size():
		neighbors[u].sort_custom(func(a: int,b: int) -> bool: return (vertices[a]-vertices[u]).angle() < (vertices[b]-vertices[u]).angle())
	var visited: Dictionary = {}
	var faces: Array[PackedVector2Array] = []
	for start in vertices.size():
		for next in neighbors[start]:
			if visited.has(Vector2i(start,next)): continue
			var u: int = start
			var v: int = next
			var polygon := PackedVector2Array()
			var touched: bool = false
			var closed: bool = false
			for step in segments.size()*4+4:
				var key := Vector2i(u,v)
				if visited.has(key):
					closed = u == start and v == next
					break
				visited[key] = true
				touched = touched or trail_edges.has(key)
				polygon.append(vertices[u])
				var options: Array = neighbors[v]
				var index: int = options.find(u)
				var w: int = options[(index-1+options.size())%options.size()]
				u = v
				v = w
			if not closed: return {"ok":false,"faces":[]}
			if touched and polygon.size() >= 3 and not Geometry2D.is_polygon_clockwise(polygon):
				for face in IslandGeometry.split_faces(IslandGeometry.clean_polygon(polygon)):
					if IslandGeometry.simple(face): faces.append(face)
	return {"ok":true,"faces":faces}

static func _cut(segment: Dictionary, p: Vector2) -> void:
	var d: Vector2 = segment.b-segment.a
	segment.cuts.append(clampf((p-segment.a).dot(d)/d.length_squared(),0,1))

static func _vertex(p: Vector2, vertices: Array[Vector2], ids: Dictionary, neighbors: Array) -> int:
	var key := Vector2i(roundi(p.x*1000),roundi(p.y*1000))
	if ids.has(key): return ids[key]
	var index := vertices.size()
	ids[key] = index
	vertices.append(Vector2(key)/1000)
	neighbors.append([])
	return index
