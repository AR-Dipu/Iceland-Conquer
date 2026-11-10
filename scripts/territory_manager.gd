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

func setup(settings: GameConfig, country: CountryMap) -> void:
	config = settings
	island = country.outline
	island_area = IslandGeometry.area(island)
	initial = country.initial_territories.duplicate(true)
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
	for other in 3:
		if other == team:
			continue
		var remaining: Array[PackedVector2Array] = []
		for p in regions[other]:
			remaining.append_array(IslandGeometry.subtract(p, polygon))
		regions[other] = remaining

func capture(team: int, trail: PackedVector2Array, departure: PackedVector2Array) -> bool:
	var enclosure := IslandGeometry.boundary_capture(departure, trail)
	if enclosure.is_empty():
		return false
	var before: float = fractions[team]
	var additions: Array[PackedVector2Array] = Geometry2D.intersect_polygons(enclosure, island)
	for addition in additions:
		# New pieces are cut against existing ownership before union, so even
		# captures that create a hole remain disjoint and area is never doubled.
		var uncovered: Array[PackedVector2Array] = [addition]
		for existing in regions[team]:
			var next: Array[PackedVector2Array] = []
			for p in uncovered:
				next.append_array(IslandGeometry.subtract(p, existing))
			uncovered = next
		for p in uncovered:
			_remove_from_others(team, p)
			regions[team].append(p)
			flashes.append({"polygon": p, "life": 0.65, "team": team})
	regions[team] = IslandGeometry.merge_regions(typed(regions[team]))
	if regions[team].size() == 1:
		var rounded: PackedVector2Array = IslandGeometry.soften(regions[team][0])
		regions[team] = Geometry2D.intersect_polygons(rounded, island)
		for p in regions[team]:
			_remove_from_others(team, p)
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
	for team in 3:
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
	for team in 3:
		var color: Color = config.team_colors[team]
		for p in regions[team]:
			if p.size() >= 3:
				var colors := PackedColorArray()
				for vertex in p:
					colors.append(color.lightened(clampf((IslandGeometry.bounds(island).end.y - vertex.y) / maxf(1.0, IslandGeometry.bounds(island).size.y), 0.0, 1.0) * 0.15))
				draw_polygon(p, colors)
				var border: PackedVector2Array = p.duplicate()
				border.append(p[0])
				colors.append(colors[0])
				draw_polyline_colors(border, colors, 1.3, true)
	for flash in flashes:
		var tint: Color = Color(1, 1, 1, float(flash.life) * 0.45)
		draw_colored_polygon(flash.polygon, tint)

