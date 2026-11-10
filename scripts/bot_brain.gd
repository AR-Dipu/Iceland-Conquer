class_name BotBrain
extends RefCounted
var waypoints: Array[Vector2] = []
var elapsed: float = 0.0
var wait: float = 3.0
var random := RandomNumberGenerator.new()
var last_position := Vector2.ZERO
var stuck: float = 0.0

func _init(seed_value: int = 1) -> void:
	random.seed = seed_value

func reset() -> void:
	waypoints.clear()
	elapsed = 0.0
	stuck = 0.0
	wait = 2.5 + random.randf() * 2.0

func steer(actor: ConquerCharacter, territory: TerritoryManager, map: CountryMap, delta: float) -> Vector2:
	wait -= delta
	if wait > 0:
		return Vector2.ZERO
	elapsed += delta
	stuck = stuck + delta if actor.position.distance_to(last_position) < 0.1 else 0.0
	last_position = actor.position
	if elapsed > 35.0 or stuck > 2.0:
		_route_home(actor, territory, map)
		elapsed = 0.0
		stuck = 0.0
	if waypoints.is_empty():
		_plan(actor, territory, map)
	if waypoints.is_empty():
		return Vector2.ZERO
	if actor.position.distance_to(waypoints[0]) < 10.0:
		waypoints.pop_front()
		if waypoints.is_empty():
			elapsed = 0
			wait = 0.6
			return Vector2.ZERO
	return actor.position.direction_to(waypoints[0])

func _route_home(actor: ConquerCharacter, territory: TerritoryManager, map: CountryMap) -> void:
	var nearest: Vector2 = actor.config.spawn_points[actor.team]
	var best: float = INF
	for p in territory.regions[actor.team]:
		var candidate: Vector2 = IslandGeometry.interior_point(p)
		if candidate.distance_to(actor.position) < best:
			best = candidate.distance_to(actor.position)
			nearest = candidate
	waypoints.assign(Array(map.route(actor.position, nearest)))

func _plan(actor: ConquerCharacter, territory: TerritoryManager, map: CountryMap) -> void:
	if not territory.owned(actor.team, actor.position):
		_route_home(actor, territory, map)
		return
	var home: Vector2 = actor.position
	var angle: float = home.angle_to_point(map.center) + random.randf_range(-2.2, 2.2)
	var outward := Vector2.from_angle(angle)
	var side := outward.orthogonal()
	var reach: float = map.home_radius * random.randf_range(1.4, 2.1)
	var targets: Array[Vector2] = [home + outward * reach + side * 90, home + outward * reach - side * 110, home - side * 45, home]
	var anchor: Vector2 = home
	for target in targets:
		var destination: Vector2 = IslandGeometry.clamp_inside(map.outline, target)
		var path: PackedVector2Array = map.route(anchor, destination)
		for p in path:
			waypoints.append(p)
		anchor = destination
