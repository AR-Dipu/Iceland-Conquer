class_name CaptureTopologyJob
extends RefCounted
## Planar half-edge faces: ownership boundaries and the excursion form a graph.
## Only bounded faces incident to the trail are eligible; no smaller-side rule.
signal continued
var owned: Array
var trail: PackedVector2Array
var deadline: int = 0
var done: bool = false
var canceled: bool = false
var started: bool = false
var result: Dictionary = {}
func _init(polygons: Array, path: PackedVector2Array) -> void:
	owned = polygons.duplicate(true)
	trail = path.duplicate()
func step(until_usec: int) -> bool:
	if done: return true
	deadline = until_usec
	if started: continued.emit()
	else:
		started = true
		_run()
	return done
func cancel() -> void:
	canceled = true
	if started and not done: continued.emit()
func _finish(value: Dictionary) -> void:
	result = value
	done = true
func _run() -> void:
	if trail.size() < 2: _finish({"ok":true,"faces":[]}); return
	var segments: Array = []
	for polygon in owned:
		if Time.get_ticks_usec() >= deadline: await continued
		if canceled: _finish({"ok":false,"faces":[]}); return
		for i in polygon.size():
			if Time.get_ticks_usec() >= deadline: await continued
			if canceled: _finish({"ok":false,"faces":[]}); return
			if polygon[i].distance_to(polygon[(i+1)%polygon.size()]) > 0.002:
				segments.append({"a":polygon[i],"b":polygon[(i+1)%polygon.size()],"trail":false,"cuts":[0.0,1.0]})
	for i in trail.size()-1:
		if Time.get_ticks_usec() >= deadline: await continued
		if canceled: _finish({"ok":false,"faces":[]}); return
		if trail[i].distance_to(trail[i+1]) > 0.002: segments.append({"a":trail[i],"b":trail[i+1],"trail":true,"cuts":[0.0,1.0]})
	if segments.size() > 6000: _finish({"ok":false,"faces":[]}); return
	# Broad phase: compare only segments sharing a spatial bucket. Keep sorted
	# pair order so topology and collinear endpoint handling remain deterministic.
	var buckets: Dictionary = {}
	var candidates: Array = []
	for i in segments.size():
		if Time.get_ticks_usec() >= deadline: await continued
		if canceled: _finish({"ok":false,"faces":[]}); return
		var s: Dictionary = segments[i]
		var lo := Vector2i(floori((minf(s.a.x,s.b.x)-0.001)/128),floori((minf(s.a.y,s.b.y)-0.001)/128))
		var hi := Vector2i(floori((maxf(s.a.x,s.b.x)+0.001)/128),floori((maxf(s.a.y,s.b.y)+0.001)/128))
		var peers: Dictionary = {}
		for x in range(lo.x,hi.x+1):
			if Time.get_ticks_usec() >= deadline: await continued
			if canceled: _finish({"ok":false,"faces":[]}); return
			for y in range(lo.y,hi.y+1):
				if Time.get_ticks_usec() >= deadline: await continued
				if canceled: _finish({"ok":false,"faces":[]}); return
				var key := Vector2i(x,y)
				for j in buckets.get(key,[]): peers[j] = true
				if not buckets.has(key): buckets[key] = []
				buckets[key].append(i)
		var ordered: Array = peers.keys()
		ordered.sort()
		candidates.append(ordered)
	for i in segments.size():
		if Time.get_ticks_usec() >= deadline: await continued
		if canceled: _finish({"ok":false,"faces":[]}); return
		var a: Dictionary = segments[i]
		for j in candidates[i]:
			if Time.get_ticks_usec() >= deadline: await continued
			if canceled: _finish({"ok":false,"faces":[]}); return
			var b: Dictionary = segments[j]
			if maxf(a.a.x,a.b.x)+0.001 < minf(b.a.x,b.b.x) or maxf(b.a.x,b.b.x)+0.001 < minf(a.a.x,a.b.x) or maxf(a.a.y,a.b.y)+0.001 < minf(b.a.y,b.b.y) or maxf(b.a.y,b.b.y)+0.001 < minf(a.a.y,a.b.y): continue
			var hit: Variant = Geometry2D.segment_intersects_segment(a.a,a.b,b.a,b.b)
			if hit != null:
				_cut(a,hit)
				_cut(b,hit)
			else:
				for p in [a.a,a.b]:
					if Time.get_ticks_usec() >= deadline: await continued
					if canceled: _finish({"ok":false,"faces":[]}); return
					if p.distance_to(Geometry2D.get_closest_point_to_segment(p,b.a,b.b)) < 0.001: _cut(b,p)
				for p in [b.a,b.b]:
					if Time.get_ticks_usec() >= deadline: await continued
					if canceled: _finish({"ok":false,"faces":[]}); return
					if p.distance_to(Geometry2D.get_closest_point_to_segment(p,a.a,a.b)) < 0.001: _cut(a,p)
	var vertices: Array[Vector2] = []
	var ids: Dictionary = {}
	var neighbors: Array = []
	var trail_edges: Dictionary = {}
	for s in segments:
		if Time.get_ticks_usec() >= deadline: await continued
		if canceled: _finish({"ok":false,"faces":[]}); return
		s.cuts.sort()
		for i in s.cuts.size()-1:
			if Time.get_ticks_usec() >= deadline: await continued
			if canceled: _finish({"ok":false,"faces":[]}); return
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
		if Time.get_ticks_usec() >= deadline: await continued
		if canceled: _finish({"ok":false,"faces":[]}); return
		neighbors[u].sort_custom(func(a: int,b: int) -> bool: return (vertices[a]-vertices[u]).angle() < (vertices[b]-vertices[u]).angle())
	var visited: Dictionary = {}
	var faces: Array[PackedVector2Array] = []
	for start in vertices.size():
		if Time.get_ticks_usec() >= deadline: await continued
		if canceled: _finish({"ok":false,"faces":[]}); return
		for next in neighbors[start]:
			if Time.get_ticks_usec() >= deadline: await continued
			if canceled: _finish({"ok":false,"faces":[]}); return
			if visited.has(Vector2i(start,next)): continue
			var u: int = start
			var v: int = next
			var polygon := PackedVector2Array()
			var touched: bool = false
			var closed: bool = false
			for step in segments.size()*4+4:
				if Time.get_ticks_usec() >= deadline: await continued
				if canceled: _finish({"ok":false,"faces":[]}); return
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
			if not closed: _finish({"ok":false,"faces":[]}); return
			if touched and polygon.size() >= 3 and not Geometry2D.is_polygon_clockwise(polygon):
				for face in IslandGeometry.split_faces(IslandGeometry.clean_polygon(polygon)):
					if Time.get_ticks_usec() >= deadline: await continued
					if canceled: _finish({"ok":false,"faces":[]}); return
					if IslandGeometry.simple(face): faces.append(face)
	_finish({"ok":true,"faces":faces}); return

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
