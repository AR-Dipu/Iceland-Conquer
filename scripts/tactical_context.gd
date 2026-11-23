class_name TacticalContext
extends RefCounted
static var distance_cache: Dictionary = {}
static func travel_seconds(distance: float, speed: float, acceleration: float, initial: float = 0) -> float:
	var start := clampf(initial,0,speed)
	var accelerate_distance := maxf(0,(speed*speed-start*start)/(2*acceleration))
	if distance <= accelerate_distance: return (sqrt(start*start+2*acceleration*distance)-start)/acceleration
	return (speed-start)/acceleration+(distance-accelerate_distance)/speed
static func route_distance(map: CountryMap, start: Vector2, finish: Vector2) -> float:
	var key := hash([map.get_instance_id(),start,finish])
	if distance_cache.has(key):
		var entry: Dictionary = distance_cache[key]
		if entry.start == start and entry.finish == finish and entry.outline == map.outline: return entry.length
	var length := _route_distance_exact(map,start,finish)
	if distance_cache.size() >= 1024: distance_cache.erase(distance_cache.keys()[0])
	distance_cache[key] = {"start":start,"finish":finish,"outline":map.outline,"length":length}
	return length
static func _route_distance_exact(map: CountryMap, start: Vector2, finish: Vector2) -> float:
	if ShoreIndex.segment_inside(map.outline,start,finish): return start.distance_to(finish)
	var route := map.route(start,finish)
	if route.is_empty(): return INF
	var length: float = 0
	var last := start
	for point in route:
		if not ShoreIndex.segment_inside(map.outline,last,point): return INF
		length += last.distance_to(point)
		last = point
	return length
static func actor_eta(actor: ConquerCharacter, distance: float, direction: Vector2) -> float:
	var speed := actor.movement_speed()
	var acceleration := actor.movement_acceleration()
	var projected := actor.velocity.dot(direction)
	# An actor moving away must brake before accelerating toward the target.
	var braking := maxf(0,-projected)/acceleration
	return braking+travel_seconds(distance,speed,acceleration,maxf(0,projected))
