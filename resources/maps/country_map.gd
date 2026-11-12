class_name CountryMap
extends Resource
## Runtime resource built from bundled, revision-pinned country geometry.
@export var country_id: String
@export var display_name: String
@export var outline := PackedVector2Array()
@export var decorative_islands: Array[PackedVector2Array] = []
@export var spawn_points: Array[Vector2] = []
@export var initial_territories: Array = [[], [], []]
@export var scenery: Array[Dictionary] = []
@export var camera_bounds := Rect2()
var land_bounds := Rect2()
var center := Vector2.ZERO
var home_radius: float = 200.0
var navigation := AStar2D.new()
var triangles: Array[PackedVector2Array] = []
var built: bool = false
var continent: String = ""
var map_rings: Array = []
var neighbors: Array = []
var sea_neighbors: Array = []
var longitude: float = 0
var latitude: float = 0

func build() -> void:
	if built: return
	built = true
	if Geometry2D.is_polygon_clockwise(outline):
		outline.reverse()
	outline = IslandGeometry.soften(outline, 17.0)
	if not IslandGeometry.simple(outline):
		var repaired: Array[PackedVector2Array] = Geometry2D.merge_polygons(outline,outline)
		repaired.sort_custom(func(a: PackedVector2Array,b: PackedVector2Array) -> bool: return IslandGeometry.area(a) > IslandGeometry.area(b))
		for piece in repaired:
			if IslandGeometry.simple(piece):
				outline = piece
				break
	land_bounds = IslandGeometry.bounds(outline)
	# Re-normalize after corner softening so each country is 2,400 units long.
	var factor: float = 2400.0 / maxf(land_bounds.size.x, land_bounds.size.y)
	var origin: Vector2 = land_bounds.position
	for i in outline.size():
		outline[i] = (outline[i] - origin) * factor
	for ring in decorative_islands:
		for i in ring.size():
			ring[i] = (ring[i] - origin) * factor
	land_bounds = IslandGeometry.bounds(outline)
	camera_bounds = land_bounds.grow(440)
	center = IslandGeometry.interior_point(outline)
	_build_navigation()
	_build_homes()
	_build_scenery()

func _build_navigation() -> void:
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	for i in range(0, indices.size(), 3):
		var tri := PackedVector2Array([outline[indices[i]], outline[indices[i + 1]], outline[indices[i + 2]]])
		var id: int = triangles.size()
		triangles.append(tri)
		navigation.add_point(id, (tri[0] + tri[1] + tri[2]) / 3.0)
	for i in triangles.size():
		for j in range(i + 1, triangles.size()):
			var shared: int = 0
			for vertex in triangles[i]:
				if triangles[j].has(vertex):
					shared += 1
			if shared == 2:
				navigation.connect_points(i, j)

func _build_homes(count: int = 3) -> void:
	spawn_points.clear()
	initial_territories = []
	for slot in count:
		initial_territories.append([])
	var candidates: Array[Vector2] = []
	for y in range(40, ceili(land_bounds.size.y), 65):
		for x in range(40, ceili(land_bounds.size.x), 65):
			var p := Vector2(x, y)
			if _safe_spawn(p) and p.distance_to(IslandGeometry.nearest(outline, p).point) > 65:
				candidates.append(p)
	if candidates.size() < count * 3:
		for y in range(10,ceili(land_bounds.size.y),15):
			for x in range(10,ceili(land_bounds.size.x),15):
				var p := Vector2(x,y)
				if _safe_spawn(p) and p.distance_to(IslandGeometry.nearest(outline,p).point) > 8:
					candidates.append(p)
	if candidates.is_empty(): candidates.append(center)
	var preferred: Vector2 = land_bounds.position + land_bounds.size * Vector2(randf_range(0.25,0.75),randf_range(0.25,0.75))
	for team in count:
		var best: float = -INF
		var chosen: Vector2 = center
		for p in candidates:
			var clearance: float = p.distance_to(IslandGeometry.nearest(outline, p).point)
			var score: float = clearance * 0.8 - p.distance_to(preferred) * 0.2
			if team > 0:
				var separation: float = INF
				for spawn in spawn_points:
					separation = minf(separation, p.distance_to(spawn))
				score = separation * 0.85 + clearance * 0.15
			if score > best:
				best = score
				chosen = p
		spawn_points.append(chosen)
	var separation: float = INF
	for i in count:
		for j in range(i + 1, count):
			separation = minf(separation, spawn_points[i].distance_to(spawn_points[j]))
	home_radius = minf(45.0, separation * 0.30)
	for team in count:
		var radius: float = minf(home_radius,spawn_points[team].distance_to(IslandGeometry.nearest(outline,spawn_points[team]).point)*0.8)
		var patch := IslandGeometry.blob(spawn_points[team], Vector2.ONE * radius, team * 1.3, 80)
		var contained: bool = true
		for vertex in patch:
			if not Geometry2D.is_point_in_polygon(vertex,outline): contained = false
		initial_territories[team] = [patch] if contained else Geometry2D.intersect_polygons(patch, outline)

func _safe_spawn(point: Vector2) -> bool:
	# Avoid exact scan-line/vertex coincidences being classified as land.
	for offset in [Vector2.ZERO,Vector2(2,0),Vector2(-2,0),Vector2(0,2),Vector2(0,-2)]:
		if not Geometry2D.is_point_in_polygon(point+offset,outline): return false
	return true

func _build_scenery() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = country_id.hash()
	var attempts: int = 0
	while scenery.size() < 48 and attempts < 1200:
		attempts += 1
		var p := Vector2(random.randf_range(0, land_bounds.size.x), random.randf_range(0, land_bounds.size.y))
		if not Geometry2D.is_point_in_polygon(p, outline):
			continue
		var near_spawn: bool = false
		for spawn in spawn_points:
			near_spawn = near_spawn or p.distance_to(spawn) < 145
		if near_spawn or p.distance_to(IslandGeometry.nearest(outline, p).point) < 28:
			continue
		var near_prop: bool = false
		for prop in scenery:
			near_prop = near_prop or p.distance_to(prop.position) < 100
		if not near_prop:
			scenery.append({"cell": scenery.size() % 3, "position": p, "width": random.randf_range(75, 135)})

func route(start: Vector2, target: Vector2) -> PackedVector2Array:
	target = IslandGeometry.clamp_inside(outline, target)
	if IslandGeometry.segment_inside(outline, start, target):
		return PackedVector2Array([target])
	var from_id: int = -1
	var to_id: int = -1
	for i in triangles.size():
		if Geometry2D.is_point_in_polygon(start, triangles[i]):
			from_id = i
		if Geometry2D.is_point_in_polygon(target, triangles[i]):
			to_id = i
	if from_id < 0 or to_id < 0:
		return PackedVector2Array([start])
	var path: PackedVector2Array = navigation.get_point_path(from_id, to_id)
	path.append(target)
	var result := PackedVector2Array()
	var anchor: Vector2 = start
	var cursor: int = 0
	while cursor < path.size():
		var farthest: int = cursor
		for j in range(cursor, path.size()):
			if IslandGeometry.segment_inside(outline, anchor, path[j]):
				farthest = j
		result.append(path[farthest])
		anchor = path[farthest]
		cursor = farthest + 1
	return result

func valid() -> bool:
	if not built: build()
	if not IslandGeometry.simple(outline) or spawn_points.size() < 3:
		return false
	for team in spawn_points.size():
		var home: Array[PackedVector2Array] = []
		for p in initial_territories[team]:
			home.append(p)
		if not IslandGeometry.contains(home, spawn_points[team]):
			return false
	return true
