class_name TerritoryManager
extends Node2D

signal territory_changed(fractions: Array[float])
signal captured(team: int, gain: float, at: Vector2)

var config: GameConfig
var island: PackedVector2Array
var regions: Array = [[], [], []]
var initial: Array = [[], [], []]
var fractions: Array[float] = [0.0, 0.0, 0.0]
var island_area: float = 1.0
var flashes: Array[Dictionary] = []
var revision: int = 0
var last_capture_error: String = ""
var nearby_actors: Array = []
var analysis_revision: int = -1
var analysis_cache: Dictionary = {}
var mesh_revision: int = -1
var mesh_teams: Array = []
var organic_cache: Dictionary = {}

func mesh_snapshot() -> Array:
	if mesh_revision == revision: return mesh_teams
	mesh_teams.clear()
	organic_cache.clear()
	for team in regions.size():
		var pieces: Array = []
		var edges := PackedVector2Array()
		var smooth: Array[PackedVector2Array] = []
		for p in regions[team]:
			pieces.append({"polygon":p,"indices":Geometry2D.triangulate_polygon(p)})
			var rounded := IslandGeometry.soften(p,12)
			for clipped in Geometry2D.intersect_polygons(rounded,p):
				if IslandGeometry.simple(clipped): smooth.append(clipped)
			for i in p.size():
				var a: Vector2 = p[i]
				var b: Vector2 = p[(i+1)%p.size()]
				var normal := Vector2(-(b-a).y,(b-a).x).normalized()*0.5
				var mid: Vector2 = (a+b)*0.5
				if owned(team,mid+normal) and owned(team,mid-normal): continue
				edges.append(a)
				edges.append(b)
		mesh_teams.append({"pieces":pieces,"edges":edges})
		organic_cache[team] = smooth
	mesh_revision = revision
	return mesh_teams

func frontiers(team: int) -> Array:
	if analysis_revision != revision:
		analysis_revision = revision
		analysis_cache.clear()
	if analysis_cache.has(team): return analysis_cache[team]
	var result: Array = []
	for polygon in regions[team]:
		var stride: int = maxi(1,polygon.size()/12)
		for i in range(0,polygon.size(),stride):
			var a: Vector2 = polygon[i]
			var b: Vector2 = polygon[(i+1)%polygon.size()]
			var tangent := a.direction_to(b)
			var inward := Vector2(-tangent.y,tangent.x)
			if Geometry2D.is_polygon_clockwise(polygon): inward = -inward
			var point: Vector2 = (a+b)*0.5
			var home: Vector2 = point+inward*3
			if owned(team,home) and not owned(team,point-inward*8) and Geometry2D.is_point_in_polygon(point-inward*8,island):
				result.append({"home":home,"direction":-inward,"clearance":point.distance_to(IslandGeometry.nearest(island,point).point)})
	analysis_cache[team] = result
	return result

func preview_capture(team: int, trail: PackedVector2Array) -> Dictionary:
	var topology := CaptureTopology.enclosed(regions[team],trail)
	if not topology.ok: return {"ok":false,"pieces":[],"area":0.0}
	var pieces: Array[PackedVector2Array] = []
	var total: float = 0
	for face in topology.faces:
		for clipped in Geometry2D.intersect_polygons(face,island):
			var uncovered: Array[PackedVector2Array] = [clipped]
			for existing in regions[team]:
				var remaining: Array[PackedVector2Array] = []
				for piece in uncovered: remaining.append_array(IslandGeometry.subtract(piece,existing))
				uncovered = remaining
			for piece in uncovered:
				var clean := IslandGeometry.clean_polygon(piece)
				if IslandGeometry.area(clean) < 8: continue
				if not IslandGeometry.simple(clean): return {"ok":false,"pieces":[],"area":0.0}
				pieces.append(clean)
				total += IslandGeometry.area(clean)
	return {"ok":true,"pieces":pieces,"area":total}

func setup(settings: GameConfig, country: CountryMap) -> void:
	config = settings
	island = country.outline
	island_area = IslandGeometry.area(island)
	initial = country.initial_territories.duplicate(true)
	fractions.resize(initial.size())
	reset_all()

func typed(polys: Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for p in polys:
		result.append(p)
	return result

func reset_all() -> void:
	regions = initial.duplicate(true)
	flashes.clear()
	_update_fractions()

func owned(team: int, point: Vector2) -> bool:
	return IslandGeometry.contains(typed(regions[team]), point)

func region_at(team: int, point: Vector2) -> PackedVector2Array:
	for p in regions[team]:
		if Geometry2D.is_point_in_polygon(point, p):
			return p
	return PackedVector2Array()

func _remove_from_others(team: int, polygon: PackedVector2Array) -> void:
	for other in regions.size():
		if other == team:
			continue
		var remaining: Array[PackedVector2Array] = []
		for p in regions[other]:
			remaining.append_array(IslandGeometry.subtract(p, polygon))
		regions[other] = remaining

func capture(team: int, trail: PackedVector2Array, departure: PackedVector2Array) -> bool:
	last_capture_error = ""
	var preview := preview_capture(team,trail)
	if not preview.ok:
		last_capture_error = "Capture could not be resolved; territory preserved."
		return false
	if preview.area <= 0: return false
	var snapshot: Array = regions.duplicate(true)
	var before: float = fractions[team]
	var additions: Array = preview.pieces
	for addition in additions:
		addition = IslandGeometry.clean_polygon(addition)
		if not IslandGeometry.simple(addition): continue
		# New pieces are cut against existing ownership before union, so even
		# captures that create a hole remain disjoint and area is never doubled.
		var uncovered: Array[PackedVector2Array] = [addition]
		for existing in regions[team]:
			var next: Array[PackedVector2Array] = []
			for p in uncovered:
				next.append_array(IslandGeometry.subtract(p, existing))
			uncovered = next
		for p in uncovered:
			p = IslandGeometry.clean_polygon(p)
			if not IslandGeometry.simple(p): continue
			_remove_from_others(team, p)
			regions[team].append(p)
			flashes.append({"polygon": p, "life": 0.45, "team": team,"origin":trail[-1]})
	regions[team] = IslandGeometry.merge_regions(typed(regions[team]))
	for polys in regions:
		for p in polys:
			if not IslandGeometry.simple(p):
				regions = snapshot
				flashes.clear()
				last_capture_error = "Capture validation failed; territory preserved."
				return false

	_update_fractions()
	if fractions[team] > before + 0.0001:
		captured.emit(team, fractions[team] - before, trail[-1])
		return true
	return false

func reset_team(team: int) -> void:
	regions[team] = initial[team].duplicate(true)
	for p in regions[team]:
		_remove_from_others(team, p)
	_update_fractions()

func _update_fractions() -> void:
	revision += 1
	for team in regions.size():
		var clean_regions: Array[PackedVector2Array] = []
		for p in regions[team]:
			var clean := IslandGeometry.clean_polygon(p)
			if IslandGeometry.simple(clean): clean_regions.append(clean)
		var total: float = 0.0
		for p in regions[team]:
			total += IslandGeometry.area(p)
		fractions[team] = clampf(total / island_area, 0.0, 1.0)
	territory_changed.emit(fractions)
	queue_redraw()

func _process(delta: float) -> void:
	if flashes.is_empty():
		return
	for flash in flashes:
		flash.life -= delta
	flashes = flashes.filter(func(f: Dictionary) -> bool: return f.life > 0.0)
	queue_redraw()

func _draw() -> void:
	if config == null:
		return
	var snapshot := mesh_snapshot()
	for team in regions.size():
		var color: Color = config.team_colors[team]
		for p in regions[team]:
			if p.size() >= 3 and not Geometry2D.triangulate_polygon(p).is_empty():
				var colors := PackedColorArray()
				for vertex in p:
					colors.append(color.lightened(clampf((IslandGeometry.bounds(island).end.y - vertex.y) / maxf(1.0, IslandGeometry.bounds(island).size.y), 0.0, 1.0) * 0.15))
				draw_polygon(p, colors)
		# A clipped rounded overlay softens sharp capture corners without changing
		# authoritative territory or painting across a rival's boundary.
		for rounded in organic_cache.get(team,[]):
			draw_colored_polygon(rounded,Color(color.lightened(0.12),0.3))
		var edges: PackedVector2Array = snapshot[team].edges
		if not edges.is_empty():
			draw_multiline(edges,Color(color.lightened(0.45),0.08),8.0,true)
			draw_multiline(edges,Color(color.lightened(0.55),0.55),1.4,true)
	for flash in flashes:
		var progress: float = 1-float(flash.life)/0.45
		var radius: float = 0
		for point in flash.polygon: radius = maxf(radius,point.distance_to(flash.origin))
		var reveal := IslandGeometry.blob(flash.origin,Vector2.ONE*maxf(1,radius*(1-pow(1-progress,3))),0,32)
		for piece in Geometry2D.intersect_polygons(flash.polygon,reveal):
			if IslandGeometry.simple(piece): draw_colored_polygon(piece,Color(config.team_colors[flash.team].lightened(0.65),float(flash.life)*0.7))

