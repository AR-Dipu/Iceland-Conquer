class_name BotBrain
extends RefCounted
var waypoints: Array[Vector2] = []
var elapsed: float = 0.0
var wait: float = 3.0
var random := RandomNumberGenerator.new()
var last_position := Vector2.ZERO
var stuck: float = 0.0
var recovery: float = 0.0

func _init(seed_value: int = 1) -> void:
	random.seed = seed_value

func reset() -> void:
	waypoints.clear()
	elapsed = 0.0
	stuck = 0.0
	recovery = 0.0
	last_position = Vector2.INF
	wait = 2.5 + random.randf() * 2.0

func steer(actor: ConquerCharacter, territory: TerritoryManager, map: CountryMap, delta: float) -> Vector2:
	wait -= delta
	if wait > 0:
		return Vector2.ZERO
	elapsed += delta
	stuck = stuck + delta if actor.position.distance_to(last_position) < 0.35 else maxf(0,stuck-delta*0.2)
	last_position = actor.position
	if elapsed > 35.0 or stuck > 2.0:
		_route_home(actor, territory, map)
		elapsed = 0.0
		stuck = 0.0
		recovery = 1.5
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
	var desired: Vector2 = actor.position.direction_to(waypoints[0])
	recovery = maxf(0,recovery-delta)
	if recovery > 0:
		var boundary: Dictionary = IslandGeometry.nearest(map.outline,actor.position)
		desired = boundary.point.direction_to(IslandGeometry.interior_point(map.outline))
	var clearance: float = actor.position.distance_to(IslandGeometry.nearest(map.outline,actor.position).point)
	var lookahead: float = clampf(clearance*0.6,8,45)
	for angle in [0.0, 0.45, -0.45, 0.9, -0.9, 1.5, -1.5, 2.2, -2.2, PI]:
		var candidate: Vector2 = desired.rotated(angle)
		var predicted: Vector2 = actor.velocity.move_toward(candidate*actor.config.bot_speed,actor.config.acceleration*delta)
		var end: Vector2 = actor.position + candidate * lookahead
		if IslandGeometry.segment_inside(map.outline, actor.position, end) and IslandGeometry.segment_inside(map.outline,actor.position,actor.position+predicted*delta):
			return candidate
	actor.velocity = Vector2.ZERO
	waypoints.clear()
	return Vector2.ZERO

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
	var reach: float = random.randf_range(110,190)
	var targets: Array[Vector2] = [home + outward * reach + side * 55, home + outward * reach - side * 55, home - side * 20, home]
	var anchor: Vector2 = home
	for target in targets:
		var destination: Vector2 = IslandGeometry.clamp_inside(map.outline, target)
		var path: PackedVector2Array = map.route(anchor, destination)
		for p in path:
			waypoints.append(p)
		anchor = destination
