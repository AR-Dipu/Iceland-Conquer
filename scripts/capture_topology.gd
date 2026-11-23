class_name CaptureTopology
extends RefCounted
## Planar half-edge faces: ownership boundaries and the excursion form a graph.
## Only bounded faces incident to the trail are eligible; no smaller-side rule.
static func enclosed(owned: Array, trail: PackedVector2Array) -> Dictionary:
	if trail.size() < 2: return {"ok":true,"faces":[]}
	var prepared := begin(owned)
	for i in trail.size()-1:
		append_segment(prepared,trail[i],trail[i+1],true)
	return enclosed_prepared(prepared)

static func begin(owned: Array) -> Dictionary:
	var prepared := {"segments":[],"buckets":{}}
	for polygon in owned:
		for i in polygon.size():
			append_segment(prepared,polygon[i],polygon[(i+1)%polygon.size()],false)
	return prepared

static func append_segment(prepared: Dictionary, start: Vector2, finish: Vector2, is_trail: bool) -> void:
	if start.distance_to(finish) <= 0.002: return
	var segments: Array = prepared.segments
	var buckets: Dictionary = prepared.buckets
	var a := {"a":start,"b":finish,"trail":is_trail,"cuts":[0.0,1.0]}
	var lo := Vector2i(floori((minf(start.x,finish.x)-0.001)/16),floori((minf(start.y,finish.y)-0.001)/16))
	var hi := Vector2i(floori((maxf(start.x,finish.x)+0.001)/16),floori((maxf(start.y,finish.y)+0.001)/16))
	var peers: Dictionary = {}
	for x in range(lo.x,hi.x+1):
		for y in range(lo.y,hi.y+1):
			var key := Vector2i(x,y)
			if not buckets.has(key): buckets[key] = []
			for index in buckets[key]: peers[index] = true
			buckets[key].append(segments.size())
	var ordered := peers.keys()
	ordered.sort()
	for index in ordered:
		var b: Dictionary = segments[index]
		if maxf(start.x,finish.x)+0.001 < minf(b.a.x,b.b.x) or maxf(b.a.x,b.b.x)+0.001 < minf(start.x,finish.x) or maxf(start.y,finish.y)+0.001 < minf(b.a.y,b.b.y) or maxf(b.a.y,b.b.y)+0.001 < minf(start.y,finish.y): continue
		var hit: Variant = Geometry2D.segment_intersects_segment(start,finish,b.a,b.b)
		if hit != null:
			_cut(a,hit)
			_cut(b,hit)
		else:
			for point in [start,finish]:
				if point.distance_to(Geometry2D.get_closest_point_to_segment(point,b.a,b.b)) < 0.001: _cut(b,point)
			for point in [b.a,b.b]:
				if point.distance_to(Geometry2D.get_closest_point_to_segment(point,start,finish)) < 0.001: _cut(a,point)
	segments.append(a)

static func enclosed_prepared(prepared: Dictionary) -> Dictionary:
	var segments: Array = prepared.segments
	if segments.size() > 6000: return {"ok":false,"faces":[]}
	var phase_began := WorkMetrics.start()
	var vertices: Array[Vector2] = []
	var ids: Dictionary = {}
	var neighbors: Array = []
	var trail_edges: Dictionary = {}
	for s in segments:
		var cuts: Array = s.cuts
		var a: Vector2 = s.a
		var b: Vector2 = s.b
		var is_trail: bool = s.trail
		cuts.sort()
		for i in cuts.size()-1:
			if cuts[i+1]-cuts[i] < 0.000001: continue
			var u := _vertex(a.lerp(b,cuts[i]),vertices,ids,neighbors)
			var v := _vertex(a.lerp(b,cuts[i+1]),vertices,ids,neighbors)
			if u == v: continue
			if not neighbors[u].has(v): neighbors[u].append(v)
			if not neighbors[v].has(u): neighbors[v].append(u)
			if is_trail:
				trail_edges[Vector2i(u,v)] = true
				trail_edges[Vector2i(v,u)] = true
	for u in vertices.size():
		var edges: Array = neighbors[u]
		if edges.size() == 2:
			var first: int = edges[0]
			var second: int = edges[1]
			if (vertices[second]-vertices[u]).angle() < (vertices[first]-vertices[u]).angle():
				edges[0] = second
				edges[1] = first
		elif edges.size() > 2:
			edges.sort_custom(func(a: int,b: int) -> bool: return (vertices[a]-vertices[u]).angle() < (vertices[b]-vertices[u]).angle())
	WorkMetrics.finish("topology_graph",phase_began)
	phase_began = WorkMetrics.start()
	var visited: Dictionary = {}
	var faces: Array[PackedVector2Array] = []
	var walk_limit := segments.size()*4+4
	for start in vertices.size():
		for next in neighbors[start]:
			if visited.has(Vector2i(start,next)): continue
			var u: int = start
			var v: int = next
			var polygon := PackedVector2Array()
			var touched: bool = false
			var closed: bool = false
			for step in walk_limit:
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
	WorkMetrics.finish("topology_faces",phase_began)
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
