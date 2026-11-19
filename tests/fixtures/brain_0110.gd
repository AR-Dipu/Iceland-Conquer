class_name FrozenBrain0110
extends RefCounted
var waypoints: Array[Vector2] = []
var elapsed: float = 0.0
var wait: float = 3.0
var random := RandomNumberGenerator.new()
var last_position := Vector2.ZERO
var stuck: float = 0.0
var recovery: float = 0.0
var planned_return := Vector2.ZERO
var plan_origin := Vector2.ZERO
var plan_fraction: float = 0
var failures: int = 0
var has_plan: bool = false
var blocked: Array[Dictionary] = []
var completed_captures: int = 0
var expected_fraction: float = 0
var replans: int = 0
const CANDIDATES: int = 12
enum PlannerState { ASSESS, APPROACH, EXPAND, RETURN, RECOVER }
var planner_state: PlannerState = PlannerState.ASSESS
var legacy_planning: bool = false
var proposals: Array = []
var scored_route: Array[Vector2] = []
var scored_value: float = 0
var scored_gain: float = 0
var scored_home := Vector2.ZERO
var proposal_revision: int = -1
var preview_checks: int = 0
var tactical_clock: float = 0
var attack_target: ConquerCharacter
var tactical_action: String = "expand"
var decision_time: float = 0
var attack_deadline: float = 0
var completed_attacks: int = 0
var abandoned_loops: int = 0
var defensive_returns: int = 0
var failed_pursuits: int = 0
var idle_seconds: float = 0
var legacy_tactics: bool = false

func _init(seed_value: int = 1) -> void:
	random.seed = seed_value

func reset() -> void:
	waypoints.clear()
	elapsed = 0.0
	stuck = 0.0
	recovery = 0.0
	last_position = Vector2.INF
	has_plan = false
	blocked.clear()
	failures = 0
	completed_captures = 0
	replans = 0
	proposals.clear()
	attack_target = null
	tactical_clock = 0
	tactical_action = "expand"
	decision_time = 0
	attack_deadline = 0
	completed_attacks = 0
	abandoned_loops = 0
	defensive_returns = 0
	failed_pursuits = 0
	idle_seconds = 0
	scored_route.clear()
	planner_state = PlannerState.ASSESS
	wait = 2.5 + random.randf() * 2.0

func steer(actor: ConquerCharacter, territory: TerritoryManager, map: CountryMap, delta: float) -> Vector2:
	decision_time += delta
	tactical_clock -= delta
	if tactical_clock <= 0:
		tactical_clock = 0.2
		_tactics(actor,territory,map)
	for item in blocked: item.life -= delta
	blocked = blocked.filter(func(item: Dictionary) -> bool: return item.life > 0)
	wait -= delta
	if wait > 0:
		idle_seconds += delta
		return Vector2.ZERO
	elapsed += delta
	if has_plan:
		planner_state = PlannerState.APPROACH if territory.owned(actor.team,actor.position) else PlannerState.RETURN if waypoints.size() <= 2 else PlannerState.EXPAND
	stuck = stuck + delta if actor.position.distance_to(last_position) < 0.35 else maxf(0,stuck-delta*0.2)
	last_position = actor.position
	if has_plan and not territory.owned(actor.team,planned_return):
		_fail_plan()
		_route_home(actor,territory,map)
	if elapsed > 35.0 or stuck > 1.5:
		_fail_plan()
		_route_home(actor, territory, map)
		elapsed = 0.0
		stuck = 0.0
		recovery = 1.5
	if waypoints.is_empty():
		if has_plan and actor.trail.points.is_empty(): _finish_plan(actor,territory)
		_plan(actor, territory, map)
	if waypoints.is_empty():
		return Vector2.ZERO
	if actor.position.distance_to(waypoints[0]) < 5.0 and (waypoints.size() > 1 or actor.trail.points.is_empty() or territory.owned(actor.team,actor.position)):
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
	var lookahead: float = clampf(clearance*0.6,8,35)
	lookahead = minf(lookahead,maxf(5,actor.position.distance_to(waypoints[0])))
	for angle in [0.0, 0.45, -0.45, 0.9, -0.9, 1.5, -1.5, 2.2, -2.2, PI]:
		var candidate: Vector2 = desired.rotated(angle)
		var predicted: Vector2 = actor.velocity.move_toward(candidate*actor.config.bot_speed,actor.config.acceleration*delta)
		var motion := ShoreMotion.solve(actor.position,predicted,maxf(delta,lookahead/actor.config.bot_speed),map.outline)
		if actor.position.distance_to(motion.position) > 0.05 and (motion.position-actor.position).dot(desired) > 0:
			return candidate
	actor.velocity = Vector2.ZERO
	waypoints.clear()
	return Vector2.ZERO

func _old_tactics(actor: ConquerCharacter, territory: TerritoryManager, map: CountryMap) -> void:
	var home := actor.position
	var home_distance: float = INF
	for polygon in territory.regions[actor.team]:
		for i in range(0,polygon.size(),maxi(1,polygon.size()/12)):
			var candidate: Vector2 = polygon[i].lerp(IslandGeometry.interior_point(polygon),0.08)
			if territory.owned(actor.team,candidate) and actor.position.distance_to(candidate) < home_distance:
				home = candidate
				home_distance = actor.position.distance_to(candidate)
	var exposed: bool = actor.trail.points.size() >= 2
	if exposed:
		for enemy in territory.nearby_actors:
			if not enemy.active or enemy.team == actor.team: continue
			for i in actor.trail.points.size()-1:
				var point := Geometry2D.get_closest_point_to_segment(enemy.position,actor.trail.points[i],actor.trail.points[i+1])
				var speed: float = enemy.config.player_speed if enemy.team == 0 else enemy.config.bot_speed
				if enemy.position.distance_to(point) < 600 and enemy.position.distance_to(point)/speed < home_distance/actor.config.bot_speed+0.5:
					tactical_action = "defend"
					attack_target = null
					waypoints.assign(Array(map.route(actor.position,home)))
					wait = 0
					return
	if is_instance_valid(attack_target):
		if not attack_target.active or attack_target.protection > 0 or attack_target.trail.points.size() < 2:
			attack_target = null
			waypoints.clear()
			tactical_action = "expand"
	var best_time: float = 2.5
	var target: ConquerCharacter
	var crossing := Vector2.ZERO
	for enemy in territory.nearby_actors:
		if not enemy.active or enemy.team == actor.team or enemy.protection > 0: continue
		for i in range(0,enemy.trail.points.size()-1,2):
			var a: Vector2 = enemy.trail.points[i]
			var b: Vector2 = enemy.trail.points[i+1]
			var hit := Geometry2D.get_closest_point_to_segment(actor.position,a,b)
			var time: float = actor.position.distance_to(hit)/actor.config.bot_speed
			if time >= best_time or time < 0.02: continue
			var end: Vector2 = hit+actor.position.direction_to(hit)*14
			if not IslandGeometry.segment_inside(map.outline,actor.position,end): continue
			# Do not grow a long vulnerable trail to chase an interception.
			if exposed and actor.position.distance_to(hit) > 90: continue
			var return_distance: float = INF
			for polygon in territory.regions[enemy.team]: return_distance = minf(return_distance,enemy.position.distance_to(IslandGeometry.nearest(polygon,enemy.position).point))
			var enemy_speed: float = enemy.config.player_speed if enemy.team == 0 else enemy.config.bot_speed
			if time+0.25 >= return_distance/enemy_speed: continue
			best_time = time
			target = enemy
			crossing = end
	if target != null:
		attack_target = target
		tactical_action = "attack"
		waypoints = [crossing]
		wait = 0

func _tactics(actor: ConquerCharacter, territory: TerritoryManager, map: CountryMap) -> void:
	if legacy_tactics:
		_old_tactics(actor,territory,map)
		return
	var home := actor.position
	var home_distance: float = INF
	for polygon in territory.regions[actor.team]:
		for i in range(0,polygon.size(),maxi(1,polygon.size()/12)):
			var candidate: Vector2 = polygon[i].lerp(IslandGeometry.interior_point(polygon),0.08)
			if territory.owned(actor.team,candidate) and actor.position.distance_to(candidate) < home_distance:
				home = candidate
				home_distance = actor.position.distance_to(candidate)
	var exposed: bool = actor.trail.points.size() >= 2
	# Only a moving intercept or an enemy already at the trail is a threat.
	var threatened: bool = false
	if exposed:
		var return_eta: float = home_distance/actor.config.bot_speed
		for enemy in territory.nearby_actors:
			if not enemy.active or enemy.team == actor.team: continue
			for i in actor.trail.points.size()-1:
				var point := Geometry2D.get_closest_point_to_segment(enemy.position,actor.trail.points[i],actor.trail.points[i+1])
				var distance: float = enemy.position.distance_to(point)
				var closing: float = enemy.velocity.dot(enemy.position.direction_to(point))
				if distance > 24 and closing < 8: continue
				var eta: float = maxf(actor.protection,distance/maxf(8,closing))
				if distance < 450 and eta+0.2 < return_eta: threatened = true
	if threatened:
		if tactical_action != "defend" or waypoints.is_empty() or not territory.owned(actor.team,waypoints[-1]):
			if has_plan: abandoned_loops += 1
			has_plan = false
			proposals.clear()
			waypoints.assign(Array(map.route(actor.position,home)))
			defensive_returns += 1
		attack_target = null
		tactical_action = "defend"
		wait = 0
		return
	if tactical_action == "defend" and exposed and not waypoints.is_empty(): return
	if is_instance_valid(attack_target):
		if attack_target.active and attack_target.protection <= 0 and attack_target.trail.points.size() >= 2 and decision_time < attack_deadline and not waypoints.is_empty(): return
		if not attack_target.active: completed_attacks += 1
		else: failed_pursuits += 1
		attack_target = null
		waypoints.clear()
		tactical_action = "expand"
	if tactical_action == "defend" and not exposed: tactical_action = "expand"
	var best_value: float = 0
	var target: ConquerCharacter
	var crossing := Vector2.ZERO
	var leader: int = -1
	var leading: float = 0
	for other in territory.nearby_actors:
		if other.active and other.team != actor.team and other.team < territory.fractions.size() and territory.fractions[other.team] > leading:
			leading = territory.fractions[other.team]
			leader = other.team
	for enemy in territory.nearby_actors:
		if not enemy.active or enemy.team == actor.team or enemy.protection > 0: continue
		for i in range(0,enemy.trail.points.size()-1,2):
			var hit := Geometry2D.get_closest_point_to_segment(actor.position,enemy.trail.points[i],enemy.trail.points[i+1])
			var time: float = actor.position.distance_to(hit)/actor.config.bot_speed
			if time < 0.02 or time > (0.65 if exposed else 3.0): continue
			var end: Vector2 = hit+actor.position.direction_to(hit)*14
			if not IslandGeometry.segment_inside(map.outline,actor.position,end): continue
			var enemy_return: float = INF
			for polygon in territory.regions[enemy.team]: enemy_return = minf(enemy_return,enemy.position.distance_to(IslandGeometry.nearest(polygon,enemy.position).point))
			var enemy_speed: float = enemy.config.player_speed if enemy.team == 0 else enemy.config.bot_speed
			if time+0.2 >= enemy_return/enemy_speed: continue
			var fraction: float = territory.fractions[enemy.team] if enemy.team < territory.fractions.size() else 0.01
			var value: float = (fraction+0.01)/maxf(0.25,time)
			if enemy.team == leader and leading >= 0.65: value *= 3
			var expansion_value: float = expected_fraction/maxf(1,(35-elapsed)) if has_plan else 0
			if value <= expansion_value*1.5 or value <= best_value: continue
			best_value = value
			target = enemy
			crossing = end
	if target != null:
		if has_plan: abandoned_loops += 1
		has_plan = false
		proposals.clear()
		attack_target = target
		attack_deadline = decision_time+3.5
		tactical_action = "attack"
		waypoints = [crossing]
		wait = 0

static func overlap_ratio(route: PackedVector2Array) -> float:
	var overlap: float = 0
	var total: float = 0
	for i in route.size()-1:
		var length: float = route[i].distance_to(route[i+1])
		total += length
		for j in range(i+1,route.size()-1):
			if route[i].direction_to(route[i+1]).dot(route[j].direction_to(route[j+1])) > -0.8: continue
			var mid: Vector2 = (route[j]+route[j+1])*0.5
			if mid.distance_to(Geometry2D.get_closest_point_to_segment(mid,route[i],route[i+1])) < 12: overlap += minf(length,route[j].distance_to(route[j+1]))
	return overlap/maxf(1,total)

func _fail_plan() -> void:
	planner_state = PlannerState.RECOVER
	if has_plan:
		blocked.append({"point":plan_origin,"life":18.0 if legacy_tactics else 6.0})
		failures = mini(5,failures+1)
	has_plan = false
	replans += 1

func _finish_plan(actor: ConquerCharacter, territory: TerritoryManager) -> void:
	var gain: float = territory.fractions[actor.team]-plan_fraction
	if gain > maxf(0.0002,expected_fraction*0.2):
		completed_captures += 1
		failures = maxi(0,failures-1)
	else:
		_fail_plan()
	has_plan = false

func _route_home(actor: ConquerCharacter, territory: TerritoryManager, map: CountryMap) -> void:
	var nearest: Vector2 = actor.config.spawn_points[actor.team]
	var best: float = INF
	for p in territory.regions[actor.team]:
		var candidate: Vector2 = IslandGeometry.interior_point(p)
		if candidate.distance_to(actor.position) < best:
			best = candidate.distance_to(actor.position)
			nearest = candidate
	waypoints.assign(Array(map.route(actor.position, nearest)))
	if waypoints.is_empty() or (waypoints.size() == 1 and waypoints[0].distance_to(actor.position) < 5):
		var escape_best: float = -INF
		var escape := actor.position
		for i in 16:
			var direction := Vector2.from_angle(float(i)*TAU/16)
			var motion := ShoreMotion.solve(actor.position,direction*actor.config.bot_speed,0.35,map.outline)
			var distance: float = actor.position.distance_to(motion.position)
			var score: float = distance-(motion.position.distance_to(nearest)-actor.position.distance_to(nearest))*0.3
			if distance > 3 and score > escape_best:
				escape_best = score
				escape = motion.position
		waypoints = [escape]

func _plan(actor: ConquerCharacter, territory: TerritoryManager, map: CountryMap) -> void:
	if legacy_planning:
		_legacy_plan(actor,territory,map)
		return
	if not territory.owned(actor.team,actor.position):
		planner_state = PlannerState.RETURN
		_route_home(actor,territory,map)
		return
	if has_plan: _finish_plan(actor,territory)
	# Rival-only captures do not invalidate this team's capture topology.
	# Restarting all searches on every other team's update starved Hard bots.
	var own_revision: int = hash(territory.regions[actor.team])
	if proposals.is_empty() or proposal_revision != own_revision:
		proposals.clear()
		scored_route.clear()
		scored_value = 0
		proposal_revision = own_revision
		preview_checks = 0
		var frontier: Array = territory.frontiers(actor.team).duplicate()
		frontier.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.home.distance_to(actor.position) < b.home.distance_to(actor.position))
		for i in mini(10,frontier.size()):
			var item: Dictionary = frontier[(i+actor.team)%frontier.size()]
			var denied: bool = false
			for bad in blocked:
				if item.home.distance_to(bad.point) < (45 if legacy_tactics else 15): denied = true
			if denied: continue
			for shape in (3 if legacy_tactics else 4):
				var reach: float = ([180.0,360.0,560.0][shape] if legacy_tactics else [50.0,100.0,180.0,300.0][shape] if territory.fractions[actor.team] > 0.75 else [90.0,180.0,360.0,560.0][shape])
				var direction: Vector2 = item.direction if legacy_tactics else item.direction.rotated([-0.55,0.0,0.55][i%3])
				proposals.append({"home":item.home,"direction":direction,"reach":reach,"shape":shape})
		if proposals.is_empty():
			if legacy_tactics: _legacy_plan(actor,territory,map)
			else: _reposition(actor,territory,map)
			return
	planner_state = PlannerState.ASSESS
	if not territory.request_planning(actor.team): return
	for work in 1:
		if proposals.is_empty(): break
		var proposal: Dictionary = proposals.pop_back()
		var home: Vector2 = proposal.home
		var direction: Vector2 = proposal.direction
		var side := direction.orthogonal()
		var reach: float = proposal.reach
		var route: Array[Vector2]
		if proposal.shape == 0:
			route = [home,home+direction*reach+side*reach*0.5,home+direction*reach-side*reach*0.5,home]
		else:
			route = [home,home+direction*reach*0.3+side*reach*0.8,home+direction*reach+side*reach*0.8,home+direction*reach-side*reach*0.8,home+direction*reach*0.3-side*reach*0.8,home]
		# Close through a different owned entry instead of retracing the exit.
		var return_point := home
		var return_score: float = INF
		for frontier in territory.frontiers(actor.team):
			var candidate: Vector2 = frontier.home
			if candidate.distance_to(home) < 20: continue
			var score: float = candidate.distance_to(route[-2])
			if score < return_score and IslandGeometry.segment_inside(map.outline,route[-2],candidate):
				return_score = score
				return_point = candidate
		route[-1] = return_point
		if not legacy_tactics and overlap_ratio(PackedVector2Array(route)) > 0.1: continue
		var valid: bool = true
		var length: float = actor.position.distance_to(home)
		for i in route.size()-1:
			if not IslandGeometry.segment_inside(map.outline,route[i],route[i+1]): valid = false
			length += route[i].distance_to(route[i+1])
		if not valid: continue
		var excursion := territory.closed_excursion(actor.team,PackedVector2Array(route))
		if excursion.size() < 3: continue
		var preview: Dictionary = territory.preview_capture(actor.team,excursion)
		preview_checks += 1
		if not preview.ok or preview.area < (400 if legacy_tactics else 8 if territory.fractions[actor.team] > 0.8 else 150): continue
		# Commit only to the loop that actually closes, rather than wandering
		# around the remainder of a route after an early home entry.
		route.assign(Array(excursion))
		length = actor.position.distance_to(home)
		for i in route.size()-1: length += route[i].distance_to(route[i+1])
		var risk: float = 0
		for other in territory.nearby_actors:
			if not other.active or other.team == actor.team: continue
			var distance: float = other.position.distance_to(home)
			if distance < 600: risk += (600-distance)/600
		var value: float = preview.area/maxf(1,length/actor.config.bot_speed)/(1+risk*0.3)
		if not legacy_tactics:
			if territory.fractions[actor.team]+preview.area/territory.island_area >= actor.config.win_fraction: value *= 10
			for other in territory.nearby_actors:
				if not other.active or other.team == actor.team or territory.fractions[other.team] < 0.65: continue
				var denied: float = 0
				for addition in preview.pieces:
					for owned_piece in territory.regions[other.team]:
						for piece in Geometry2D.intersect_polygons(addition,owned_piece): denied += IslandGeometry.area(piece)
				value *= 1+denied/maxf(1,preview.area)
		if value > scored_value:
			scored_value = value
			scored_gain = preview.area
			scored_route = route
			scored_home = home
	if not proposals.is_empty(): return
	if scored_route.is_empty():
		if legacy_tactics: _legacy_plan(actor,territory,map)
		else: _reposition(actor,territory,map)
		return
	waypoints.assign(Array(map.route(actor.position,scored_home)))
	waypoints.append_array(scored_route.slice(1))
	planned_return = scored_route[-1]
	plan_origin = scored_home
	plan_fraction = territory.fractions[actor.team]
	expected_fraction = scored_gain/territory.island_area
	has_plan = true
	planner_state = PlannerState.APPROACH
	elapsed = 0

func _reposition(actor: ConquerCharacter, territory: TerritoryManager, map: CountryMap) -> void:
	var best: float = INF
	var target := actor.position
	for item in territory.frontiers(actor.team):
		var distance: float = actor.position.distance_to(item.home)
		if distance < 25 or distance >= best: continue
		var inside: bool = true
		for i in 9:
			if not territory.owned(actor.team,actor.position.lerp(item.home,float(i)/8)): inside = false
		if inside:
			best = distance
			target = item.home
	if best < INF: waypoints = [target]
	wait = 0.15

func _legacy_plan(actor: ConquerCharacter, territory: TerritoryManager, map: CountryMap) -> void:
	if not territory.owned(actor.team, actor.position):
		_route_home(actor, territory, map)
		return
	if has_plan: _finish_plan(actor,territory)
	var best: float = 0
	var best_route: Array[Vector2] = []
	var best_home := actor.position
	var regions: Array = territory.regions[actor.team]
	if regions.is_empty(): return
	for attempt in CANDIDATES:
		var region: PackedVector2Array = regions[random.randi_range(0,regions.size()-1)]
		var center := IslandGeometry.interior_point(region)
		var vertex: Vector2 = region[random.randi_range(0,region.size()-1)]
		var home: Vector2 = center.lerp(vertex,0.8)
		if not territory.owned(actor.team,home): home = center
		var forbidden: bool = false
		for item in blocked:
			if home.distance_to(item.point) < 65: forbidden = true
		if forbidden: continue
		var direction: Vector2 = center.direction_to(vertex).rotated(random.randf_range(-0.6,0.6))
		# Retain short feasible loops near narrow coasts even after failed plans.
		var reach: float = random.randf_range(110,200) if attempt%3 == 0 else random.randf_range(210,360)
		var width: float = reach*random.randf_range(0.7,1.1)
		var a: Vector2 = home+direction*reach+direction.orthogonal()*width*0.5
		var b: Vector2 = home+direction*reach-direction.orthogonal()*width*0.5
		if not IslandGeometry.segment_inside(map.outline,home,a) or not IslandGeometry.segment_inside(map.outline,a,b) or not IslandGeometry.segment_inside(map.outline,b,home): continue
		var polygon := PackedVector2Array([home,a,b])
		var useful: float = 0
		for sample in 20:
			var u: float = random.randf()
			var v: float = random.randf()
			if u+v > 1:
				u = 1-u
				v = 1-v
			var p: Vector2 = home+(a-home)*u+(b-home)*v
			if not territory.owned(actor.team,p): useful += 1
		var gain: float = IslandGeometry.area(polygon)*useful/20.0
		var length: float = actor.position.distance_to(home)+home.distance_to(a)+a.distance_to(b)+b.distance_to(home)
		var score: float = gain/maxf(1,length)
		if score <= best or gain < 250: continue
		best = score
		expected_fraction = gain/territory.island_area
		best_home = home
		best_route = [a,b,home]
	if best_route.is_empty():
		wait = 0.4
		failures = mini(5,failures+1)
		if blocked.size() > 0: blocked.pop_front()
		# Relocate along owned land toward a different frontier before trying again.
		var region: PackedVector2Array = regions[random.randi_range(0,regions.size()-1)]
		var point := IslandGeometry.interior_point(region)
		if actor.position.distance_to(point) > 15: waypoints.assign(Array(map.route(actor.position,point)))
		return
	waypoints.assign(Array(map.route(actor.position,best_home)))
	waypoints.append_array(best_route)
	planned_return = best_home
	plan_origin = best_home
	plan_fraction = territory.fractions[actor.team]
	has_plan = true
	elapsed = 0
