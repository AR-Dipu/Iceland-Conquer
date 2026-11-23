class_name BotBrain
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
var urgent_scan_at := -INF
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
var pending_preview: CapturePreviewJob
var pending_candidate: Dictionary = {}
var planning_owner: TerritoryManager
var planning_team: int = -1
var frontier_work: Array = []
var frontier_cursor: int = 0
var search_started: bool = false
var plan_timeout: float = 60
var plan_direction := Vector2.ZERO
var interrupted_route: Array[Vector2] = []
var interrupted_owner_hash: int = -1
var recovery_preview: CapturePreviewJob
var recovery_route: Array[Vector2] = []
var recovery_attempted := false

func _init(seed_value: int = 1) -> void:
	random.seed = seed_value

func reset() -> void:
	_clear_search()
	proposal_revision = -1
	waypoints.clear()
	interrupted_route.clear()
	recovery_preview = null
	recovery_route.clear()
	recovery_attempted = false
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
	tactical_clock = random.randf()*0.2
	tactical_action = "expand"
	urgent_scan_at = -INF
	decision_time = 0
	attack_deadline = 0
	completed_attacks = 0
	abandoned_loops = 0
	defensive_returns = 0
	failed_pursuits = 0
	idle_seconds = 0
	scored_route.clear()
	planner_state = PlannerState.ASSESS
	wait = random.randf() * 0.25

func steer(actor: ConquerCharacter, territory: TerritoryManager, map: CountryMap, delta: float) -> Vector2:
	decision_time += delta
	tactical_clock -= delta
	if tactical_clock <= 0 or (decision_time >= urgent_scan_at and tactical_action != "defend" and _immediate_danger(actor,territory)):
		tactical_clock = 0.2
		urgent_scan_at = decision_time + 0.06
		var began := WorkMetrics.start()
		_tactics(actor,territory,map)
		WorkMetrics.finish("tactical_scan",began)
	for item in blocked: item.life -= delta
	blocked = blocked.filter(func(item: Dictionary) -> bool: return item.life > 0)
	wait -= delta
	if wait > 0:
		idle_seconds += delta
		return Vector2.ZERO
	elapsed += delta
	if has_plan:
		planner_state = PlannerState.APPROACH if territory.owned(actor.team,actor.position) else PlannerState.RETURN if waypoints.size() <= 2 else PlannerState.EXPAND
	stuck = stuck + delta if not waypoints.is_empty() and actor.position.distance_to(last_position) < 0.35 else maxf(0,stuck-delta*0.2)
	last_position = actor.position
	if has_plan and not territory.owned(actor.team,planned_return):
		_fail_plan()
		waypoints.clear()
	if (has_plan and elapsed > plan_timeout) or stuck > 2.5:
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
	var clearance: float = actor.position.distance_to(ShoreIndex.nearest(map.outline,actor.position).point)
	var lookahead: float = clampf(clearance*0.6,8,35)
	lookahead = minf(lookahead,maxf(5,actor.position.distance_to(waypoints[0])))
	for angle in [0.0, 0.45, -0.45, 0.9, -0.9, 1.5, -1.5, 2.2, -2.2, PI]:
		var candidate: Vector2 = desired.rotated(angle)
		var predicted: Vector2 = actor.velocity.move_toward(candidate*actor.config.bot_speed,actor.config.acceleration*delta)
		var motion := ShoreMotion.solve(actor.position,predicted,maxf(delta,lookahead/actor.config.bot_speed),map.outline,"shore_prediction")
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
			for i in actor.trail.near_segments(enemy.position,450):
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
		for i in enemy.trail.near_segments(actor.position,actor.config.bot_speed*(0.65 if exposed else 3.0)):
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
	var state := territory.tactical_state(actor,map)
	var home: Vector2 = state.home
	var exposed := actor.trail.points.size() >= 2
	var return_eta: float = state.return_eta
	var loop_eta: float = return_eta
	if has_plan and not waypoints.is_empty():
		var remaining: float = 0
		var last := actor.position
		for index in waypoints.size():
			var point := waypoints[index]
			remaining += TacticalContext.route_distance(map,last,point) if index == 0 else last.distance_to(point)
			last = point
		loop_eta = remaining/actor.config.bot_speed
		return_eta = minf(return_eta,loop_eta)
	var earliest_threat: float = INF
	var threats: Dictionary = {}
	if exposed:
		for enemy in territory.nearby_actors:
			if not enemy.active or enemy.team == actor.team: continue
			var nearest: float = INF
			var target := actor.position
			for index in actor.trail.near_segments(enemy.position,450):
				var p := Geometry2D.get_closest_point_to_segment(enemy.position,actor.trail.points[index],actor.trail.points[index+1])
				if enemy.position.distance_squared_to(p) < nearest:
					nearest = enemy.position.distance_squared_to(p)
					target = p
			if nearest > 450*450: continue
			var closing: float = enemy.velocity.dot(enemy.position.direction_to(target))
			if nearest > 24*24 and closing < 8: continue
			var length := TacticalContext.route_distance(map,enemy.position,target)
			var eta := TacticalContext.actor_eta(enemy,length,enemy.position.direction_to(target))
			# A distant actor traveling mostly across the trail is not already
			# committed to a full-speed turn toward it. Retain observed closing
			# time as well as the acceleration/reachability lower bound.
			if nearest > 24*24: eta = maxf(eta,length/maxf(8,closing))
			var arrival := maxf(actor.protection,eta)
			threats[enemy.team] = arrival
			earliest_threat = minf(earliest_threat,arrival)
	var threatened: bool = exposed and earliest_threat+0.2 < return_eta
	if threatened:
		# Cutting the pursuer first can close the danger faster than retreating.
		# Ignore only that pursuer's threat; every other attacker still matters.
		var counter: Dictionary = {}
		var counter_target: ConquerCharacter
		for enemy in territory.nearby_actors:
			if not enemy.active or not threats.has(enemy.team): continue
			var other_threat: float = INF
			for team in threats:
				if team != enemy.team: other_threat = minf(other_threat,threats[team])
			var opportunity := _interception(actor,enemy,territory,map,other_threat)
			if not opportunity.is_empty() and opportunity.eta+0.15 < threats[enemy.team] and (counter.is_empty() or opportunity.eta < counter.eta):
				counter = opportunity
				counter_target = enemy
		if counter_target != null:
			if attack_target == counter_target and not waypoints.is_empty() and decision_time < attack_deadline: return
			if has_plan: abandoned_loops += 1
			_stash_capture(territory,actor.team)
			has_plan = false
			_clear_search()
			attack_target = counter_target
			attack_deadline = decision_time+4.0
			tactical_action = "attack"
			waypoints.assign(counter.route)
			wait = 0
			return
		if tactical_action != "defend" or waypoints.is_empty() or not territory.owned(actor.team,waypoints[-1]):
			interrupted_route.clear()
			if has_plan: abandoned_loops += 1
			has_plan = false
			_clear_search()
			waypoints = _safe_return(actor,territory,map,home)
			defensive_returns += 1
		attack_target = null
		tactical_action = "defend"
		wait = 0
		return
	if tactical_action == "defend" and exposed and not waypoints.is_empty(): return
	var human: ConquerCharacter
	var human_attack: Dictionary = {}
	if not territory.nearby_actors.is_empty():
		human = territory.nearby_actors[0]
		if human.team == 0 and human != actor:
			human_attack = _interception(actor,human,territory,map,earliest_threat)
	if not human_attack.is_empty() and attack_target != human:
		if attack_target != null and not attack_target.active: completed_attacks += 1
		if has_plan: abandoned_loops += 1
		_stash_capture(territory,actor.team)
		has_plan = false
		_clear_search()
		attack_target = human
		attack_deadline = decision_time+4.0
		tactical_action = "attack"
		waypoints.assign(human_attack.route)
		wait = 0
		return
	if is_instance_valid(attack_target):
		var active := human_attack if attack_target == human else _interception(actor,attack_target,territory,map,earliest_threat)
		if not active.is_empty() and decision_time < attack_deadline and not waypoints.is_empty(): return
		if not attack_target.active: completed_attacks += 1
		else: failed_pursuits += 1
		attack_target = null
		waypoints.clear()
		tactical_action = "expand"
		if _resume_capture(actor,territory,map): return
	if tactical_action == "defend" and not exposed: tactical_action = "expand"
	var leader: int = -1
	var leading: float = 0
	for other in territory.nearby_actors:
		if other.active and other.team != actor.team and territory.fractions[other.team] > leading:
			leading = territory.fractions[other.team]
			leader = other.team
	var best: Dictionary = {}
	var best_value: float = 0
	var target: ConquerCharacter
	var expansion_value: float = expected_fraction/maxf(1,loop_eta) if has_plan else 0
	for enemy in territory.nearby_actors:
		if not enemy.active or enemy.team == actor.team or enemy.team == 0: continue
		var other_threat: float = INF
		for team in threats:
			if team != enemy.team: other_threat = minf(other_threat,threats[team])
		var candidate := _interception(actor,enemy,territory,map,other_threat)
		if candidate.is_empty(): continue
		var reward: float = territory.fractions[enemy.team]
		# Score the land actually inherited, with a bounded proportional
		# elimination benefit, over both interception and safe-return time.
		# A flat bonus previously made distant tiny patches look too valuable.
		var value: float = (reward+0.06)/maxf(0.25,candidate.eta+candidate.escape*0.5)
		if enemy.team == leader and leading >= 0.65: value *= 3
		if (territory.fractions[actor.team] >= actor.config.win_fraction or value > expansion_value*0.8) and value > best_value:
			best_value = value
			best = candidate
			target = enemy
	if target != null:
		if has_plan: abandoned_loops += 1
		_stash_capture(territory,actor.team)
		has_plan = false
		_clear_search()
		attack_target = target
		attack_deadline = decision_time+4.0
		tactical_action = "attack"
		waypoints.assign(best.route)
		wait = 0

func _stash_capture(territory: TerritoryManager, team: int) -> void:
	if not has_plan or waypoints.is_empty(): return
	interrupted_route = waypoints.duplicate()
	interrupted_owner_hash = hash(territory.regions[team])

func _resume_capture(actor: ConquerCharacter, territory: TerritoryManager, map: CountryMap) -> bool:
	var route := interrupted_route.duplicate()
	interrupted_route.clear()
	if route.is_empty() or actor.trail.points.size() < 2 or territory.owned(actor.team,actor.position): return false
	if interrupted_owner_hash != hash(territory.regions[actor.team]) or not territory.owned(actor.team,planned_return): return false
	if not ShoreIndex.segment_inside(map.outline,actor.position,route[0]): return false
	var excursion := actor.trail.points.duplicate()
	excursion.append(actor.position)
	excursion.append_array(PackedVector2Array(route))
	var closed := territory.closed_excursion(actor.team,excursion)
	if closed.is_empty() or overlap_ratio(closed) > 0.1: return false
	waypoints = route
	has_plan = true
	plan_timeout += 4.0
	wait = 0
	return true

func _interception(actor: ConquerCharacter, enemy: ConquerCharacter, territory: TerritoryManager, map: CountryMap, threat_eta: float) -> Dictionary:
	if not enemy.active or enemy.protection > 0 or enemy.trail.points.size() < 2: return {}
	var candidates: Array = []
	for index in enemy.trail.near_segments(actor.position,actor.config.bot_speed*4):
		var point := Geometry2D.get_closest_point_to_segment(actor.position,enemy.trail.points[index],enemy.trail.points[index+1])
		var distance := actor.position.distance_squared_to(point)
		var insert_at := candidates.size()
		while insert_at > 0 and distance < candidates[insert_at-1].distance: insert_at -= 1
		if insert_at >= 3: continue
		candidates.insert(insert_at,{"point":point,"distance":distance})
		if candidates.size() > 3: candidates.pop_back()
	if candidates.is_empty(): return {}
	var closing_state := territory.tactical_state(enemy,map)
	if closing_state.return_eta <= 0: return {}
	for i in mini(3,candidates.size()):
		var hit: Vector2 = candidates[i].point
		var lower_eta: float = maxf(0.0,sqrt(candidates[i].distance)-actor.config.trail_hit_radius)/actor.movement_speed()
		if lower_eta > 4 or lower_eta+0.08 >= closing_state.return_eta or lower_eta+0.2 >= threat_eta: continue
		var heading := actor.position.direction_to(hit)
		if heading == Vector2.ZERO: heading = actor.heading if actor.heading != Vector2.ZERO else Vector2.RIGHT
		var end := hit+heading*14
		var route := PackedVector2Array([end])
		var direct := ShoreIndex.segment_inside(map.outline,actor.position,end)
		if not direct:
			end = hit
			route = map.route(actor.position,end)
			if route.is_empty(): continue
		var approach := actor.position
		var travel_distance := 0.0
		for step in route:
			if not direct and not ShoreIndex.segment_inside(map.outline,approach,step):
				travel_distance = INF
				break
			travel_distance += approach.distance_to(step)
			approach = step
		# Contact occurs at collision radius, not at the waypoint beyond the trail.
		var length := maxf(0,travel_distance-end.distance_to(hit)-actor.config.trail_hit_radius)
		var eta := TacticalContext.actor_eta(actor,length,actor.position.direction_to(route[0]))
		if eta > 4 or eta+0.08 >= closing_state.return_eta: continue
		var escape: float = 0
		if not territory.owned(actor.team,end):
			var home := territory.safe_home(actor.team,end)
			escape = TacticalContext.route_distance(map,end,home)/actor.config.bot_speed
		if actor.trail.points.size() >= 2 and eta+escape+0.2 >= threat_eta: continue
		return {"point":end,"route":Array(route),"eta":eta,"escape":escape}
	return {}

func _immediate_danger(actor: ConquerCharacter, territory: TerritoryManager) -> bool:
	if actor.protection > 0 or actor.trail.points.size() < 2: return false
	for enemy in territory.nearby_actors:
		if not enemy.active or enemy.team == actor.team or enemy.velocity.length_squared() < 1: continue
		for index in actor.trail.near_segments(enemy.position,24):
			var point := Geometry2D.get_closest_point_to_segment(enemy.position,actor.trail.points[index],actor.trail.points[index+1])
			if enemy.position.distance_to(point) < 24 and enemy.velocity.dot(enemy.position.direction_to(point)) > 0: return true
	return false


static func overlap_ratio(route: PackedVector2Array) -> float:
	var overlap: float = 0
	var total: float = 0
	var cells: Dictionary = {}
	var lengths := PackedFloat64Array()
	var directions := PackedVector2Array()
	var midpoints := PackedVector2Array()
	for i in route.size()-1:
		var offset := route[i+1]-route[i]
		var length := offset.length()
		lengths.append(length)
		total += length
		directions.append(offset.normalized())
		var mid := (route[i]+route[i+1])*0.5
		midpoints.append(mid)
		var cell := Vector2i(floori(mid.x/32.0),floori(mid.y/32.0))
		if not cells.has(cell): cells[cell] = []
		cells[cell].append(i)
	for i in lengths.size():
		var a := route[i]
		var b := route[i+1]
		var lower := Vector2i(floori((minf(a.x,b.x)-12)/32.0),floori((minf(a.y,b.y)-12)/32.0))
		var upper := Vector2i(floori((maxf(a.x,b.x)+12)/32.0),floori((maxf(a.y,b.y)+12)/32.0))
		for x in range(lower.x,upper.x+1):
			for y in range(lower.y,upper.y+1):
				for j in cells.get(Vector2i(x,y),[]):
					if j <= i or directions[i].dot(directions[j]) > -0.8: continue
					var mid := midpoints[j]
					if mid.distance_to(Geometry2D.get_closest_point_to_segment(mid,a,b)) < 12:
						overlap += minf(lengths[i],lengths[j])
	return overlap/maxf(1,total)

func _fail_plan() -> void:
	interrupted_route.clear()
	planner_state = PlannerState.RECOVER
	if has_plan:
		blocked.append({"point":plan_origin,"direction":plan_direction,"life":15.0})
		failures = mini(5,failures+1)
	has_plan = false
	tactical_action = "recover"
	_clear_search()
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
	var began := Time.get_ticks_usec()
	_plan_work(actor,territory,map)
	territory.planning_spent_usec += Time.get_ticks_usec()-began

func _plan_work(actor: ConquerCharacter, territory: TerritoryManager, map: CountryMap) -> void:
	if legacy_planning:
		_legacy_plan(actor,territory,map)
		return
	if not territory.owned(actor.team,actor.position):
		planner_state = PlannerState.RETURN
		if _recover_excursion(actor,territory,map): return
		_route_home(actor,territory,map)
		return
	recovery_attempted = false
	var own_hash: int = hash(territory.regions[actor.team])
	if proposal_revision != own_hash:
		_clear_search()
		proposal_revision = own_hash
	if pending_preview != null:
		if territory.planning_budget < 0 and not pending_preview.done: pending_preview.step(Time.get_ticks_usec()+2000)
		if pending_preview.canceled:
			pending_preview = null
			return
		if not pending_preview.done: return
		var preview: Dictionary = pending_preview.result
		pending_preview = null
		preview_checks += 1
		if preview.ok and preview.area > (8 if territory.fractions[actor.team] > 0.8 else 150):
			var route: PackedVector2Array = pending_candidate.path
			var length: float = pending_candidate.length
			var value: float = (preview.area + _enclosure_value(actor,territory,preview.pieces.slice(0,preview.get("enclosed_count",0))))/maxf(1,length/actor.config.bot_speed)
			value /= 1+pending_candidate.risk*0.15
			if territory.fractions[actor.team]+preview.area/territory.island_area >= actor.config.win_fraction: value *= 10
			if value > scored_value:
				scored_value = value
				scored_gain = preview.area
				scored_route.assign(Array(route))
				scored_home = pending_candidate.home
	if preview_checks >= 6 and not scored_route.is_empty():
		_commit_plan(actor,map)
		return
	if not territory.request_planning(actor.team): return
	planning_owner = territory
	planning_team = actor.team
	planner_state = PlannerState.ASSESS
	if not search_started:
		frontier_work = territory.frontiers(actor.team).duplicate()
		var rival := _hunt_target(actor,territory)
		var focus := rival.position if rival != null else actor.position
		frontier_work.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
			return a.home.distance_to(actor.position)*0.35+a.home.distance_to(focus) < b.home.distance_to(actor.position)*0.35+b.home.distance_to(focus))
		if frontier_work.size() > 10: frontier_work.resize(10)
		search_started = true
		frontier_cursor = 0
	if frontier_cursor < frontier_work.size():
		_generate_frontier(actor,territory,map,frontier_work[frontier_cursor])
		frontier_cursor += 1
		if frontier_cursor == frontier_work.size():
			proposals.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.estimate > b.estimate)
		return
	if proposals.is_empty() or preview_checks >= 24:
		if not scored_route.is_empty(): _commit_plan(actor,map)
		else:
			_clear_search()
			_reposition(actor,territory,map)
		return
	var candidate: Dictionary = proposals.pop_front()
	var route: PackedVector2Array = candidate.path
	for i in route.size()-1:
		if not ShoreIndex.segment_inside(map.outline,route[i],route[i+1]): return
	var excursion := territory.closed_excursion(actor.team,route)
	if excursion.size() < 4 or overlap_ratio(excursion) > 0.1: return
	candidate.path = excursion
	candidate.length = actor.position.distance_to(candidate.home)
	for i in excursion.size()-1: candidate.length += excursion[i].distance_to(excursion[i+1])
	pending_candidate = candidate
	pending_preview = territory.start_preview(actor.team,excursion)

func _recover_excursion(actor: ConquerCharacter, territory: TerritoryManager, map: CountryMap) -> bool:
	if recovery_preview != null:
		if territory.planning_budget < 0 and not recovery_preview.done:
			recovery_preview.step(Time.get_ticks_usec()+2000)
		if not recovery_preview.done: return true
		var result := recovery_preview.result
		var valid: bool = not recovery_preview.canceled and result.get("ok",false) and result.get("area",0.0) > 150
		recovery_preview = null
		if valid and not recovery_route.is_empty() and territory.owned(actor.team,recovery_route[-1]):
			waypoints = recovery_route.duplicate()
			return true
		return false
	if recovery_attempted or actor.trail.points.size() < 3 or actor.trail.points.size() > 180: return false
	if not territory.request_planning(actor.team): return false
	recovery_attempted = true
	var best_path := PackedVector2Array()
	var best_score := 0.0
	var frontier := territory.frontiers(actor.team).duplicate()
	frontier.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.home.distance_squared_to(actor.position) < b.home.distance_squared_to(actor.position))
	for i in mini(frontier.size(),6):
		var home: Vector2 = frontier[i].home
		if not ShoreIndex.segment_inside(map.outline,actor.position,home): continue
		var path := actor.trail.points.duplicate()
		path.append(actor.position)
		path.append(home)
		var direction := actor.position.direction_to(home)
		var reverse_distance := 0.0
		for index in actor.trail.query_segments(actor.position,home,12):
			var a := actor.trail.points[index]
			var b := actor.trail.points[index+1]
			if direction.dot(a.direction_to(b)) < -0.8 and IslandGeometry.segment_distance(actor.position,home,a,b) < 12:
				reverse_distance += a.distance_to(b)
		if reverse_distance > actor.position.distance_to(home)*0.1: continue
		var score := IslandGeometry.area(path)/maxf(40.0,actor.position.distance_to(home))
		if score <= best_score: continue
		best_score = score
		best_path = path
		recovery_route = [home]
	if best_path.is_empty(): return false
	recovery_preview = territory.start_preview(actor.team,best_path)
	return recovery_preview != null

func _generate_frontier(actor: ConquerCharacter, territory: TerritoryManager, map: CountryMap, frontier: Dictionary) -> void:
	var began := WorkMetrics.start()
	var home: Vector2 = frontier.home
	var direction: Vector2 = frontier.direction
	var available: float = ShoreIndex.reach(map.outline,home,direction,750)
	available = territory.open_reach(actor.team,home,direction,available)
	for depth_factor in [0.1,0.2,0.4,0.65,0.9]:
		var depth: float = minf(600,available*depth_factor)
		if territory.fractions[actor.team] > 0.8: depth = minf(depth,220)
		if depth < 35: continue
		for handedness in [-1.0,1.0]:
			var side: Vector2 = direction.orthogonal()*handedness
			var width: float = minf(depth*0.65,250)
			var entry := home
			var best: float = INF
			for item in frontier_work:
				if item.home.distance_to(home) < 20: continue
				var score: float = item.home.distance_to(home-side*width)
				if score < best:
					best = score
					entry = item.home
			var forbidden: bool = false
			for bad in blocked:
				if home.distance_to(bad.point) < 18 and direction.dot(bad.get("direction",direction)) > 0.7: forbidden = true
			if forbidden: continue
			var path := PackedVector2Array([home,home+direction*depth*0.25+side*width,home+direction*depth+side*width,home+direction*depth-side*width,entry+direction*depth*0.25-side*width*0.3,entry])
			var inside: bool = true
			var unowned: float = 0
			for point in path:
				if not Geometry2D.is_point_in_polygon(point,map.outline): inside = false
				if not territory.owned(actor.team,point): unowned += 1
			if not inside or unowned < 3: continue
			var length: float = actor.position.distance_to(home)
			for i in path.size()-1: length += path[i].distance_to(path[i+1])
			var risk: float = 0
			for enemy in territory.nearby_actors:
				if enemy.active and enemy.team != actor.team and enemy.position.distance_to(home) < 200: risk += 1
			var estimate: float = depth*width*1.5*(unowned/6)/maxf(1,length/actor.config.bot_speed)/(1+risk*0.15)
			proposals.append({"path":path,"home":home,"length":length,"estimate":estimate,"risk":risk})
	_generate_coastal_routes(actor,territory,map,home,direction)
	_generate_hunt_routes(actor,territory,map,home)
	WorkMetrics.finish("planning_candidates",began)

func _hunt_target(actor: ConquerCharacter, territory: TerritoryManager) -> ConquerCharacter:
	var target: ConquerCharacter
	var best := INF
	for rival in territory.nearby_actors:
		if not rival.active or rival.team == actor.team: continue
		var score: float = actor.position.distance_to(rival.position)/(1.0+territory.fractions[rival.team]*4.0)
		if rival.team == 0 and actor.position.distance_squared_to(rival.position) <= 490000.0: return rival
		if score < best:
			best = score
			target = rival
	return target

func _enclosure_value(actor: ConquerCharacter, territory: TerritoryManager, pieces: Array) -> float:
	var score := 0.0
	for rival in territory.nearby_actors:
		if not rival.active or rival.team == actor.team: continue
		for polygon in pieces:
			if Geometry2D.is_point_in_polygon(rival.position,polygon):
				score += territory.island_area*(0.22 if rival.team == 0 else 0.10)+territory.island_area*territory.fractions[rival.team]
				break
	return score

func _generate_hunt_routes(actor: ConquerCharacter, territory: TerritoryManager, map: CountryMap, home: Vector2) -> void:
	var target := _hunt_target(actor,territory)
	if target == null or territory.owned(actor.team,target.position): return
	var gap := home.distance_to(target.position)
	if gap < 18 or gap > 700: return
	var direction := home.direction_to(target.position)
	var lateral := direction.orthogonal()
	var center := target.position
	for width in [24.0,54.0,100.0]:
		var path := PackedVector2Array([home,center+lateral*width,center+direction*width,center-lateral*width,home])
		var departure := home.direction_to(path[1])
		var recently_failed := false
		for attempt in blocked:
			if home.distance_to(attempt.point) < 18 and departure.dot(attempt.get("direction",departure)) > 0.7:
				recently_failed = true
				break
		if recently_failed: continue
		var valid := true
		var length := actor.position.distance_to(home)
		for i in path.size()-1:
			if not ShoreIndex.segment_inside(map.outline,path[i],path[i+1]):
				valid = false
				break
			length += path[i].distance_to(path[i+1])
		if not valid: continue
		var reward := IslandGeometry.area(path)+territory.island_area*(0.10+territory.fractions[target.team])
		proposals.append({"path":path,"home":home,"length":length,"estimate":reward/maxf(1,length/actor.config.bot_speed),"risk":0.0})

func _generate_coastal_routes(actor: ConquerCharacter, territory: TerritoryManager, map: CountryMap, home: Vector2, outward: Vector2) -> void:
	var coast: Dictionary = ShoreIndex.nearest(map.outline,home)
	if home.distance_squared_to(coast.point) > 225.0*225.0: return
	var inward: Vector2 = coast.point.direction_to(home)
	var tangent := inward.orthogonal()
	for side in [-1.0,1.0]:
		var travel: Vector2 = tangent*side
		for reach in [100.0,220.0]:
			var outer: Vector2 = coast.point + inward*22 + travel*reach
			var inner: Vector2 = home + inward*minf(90,reach*0.42) + travel*reach
			var path := PackedVector2Array([home,home.lerp(coast.point,0.55)+travel*35,outer,inner,home])
			if outward.dot(home.direction_to(path[1])) < 0.15: continue
			var available := true
			for i in path.size()-1:
				if not ShoreIndex.segment_inside(map.outline,path[i],path[i+1]):
					available = false
					break
			if not available or territory.owned(actor.team,outer) or territory.owned(actor.team,inner): continue
			var length := actor.position.distance_to(home)
			for i in path.size()-1: length += path[i].distance_to(path[i+1])
			var risk := 0.0
			for enemy in territory.nearby_actors:
				if enemy.active and enemy.team != actor.team and enemy.position.distance_squared_to(outer) < 40000:
					risk += 1.0
			var estimate := IslandGeometry.area(path)/maxf(1,length/actor.config.bot_speed)/(1+risk*0.15)
			proposals.append({"path":path,"home":home,"length":length,"estimate":estimate,"risk":risk})

func _commit_plan(actor: ConquerCharacter, map: CountryMap) -> void:
	waypoints.assign(Array(map.route(actor.position,scored_home)))
	waypoints.append_array(scored_route.slice(1))
	planned_return = scored_route[-1]
	plan_origin = scored_home
	plan_direction = scored_route[0].direction_to(scored_route[1])
	plan_fraction = planning_owner.fractions[actor.team]
	expected_fraction = scored_gain/maxf(1,planning_owner.island_area)
	var length: float = actor.position.distance_to(scored_home)
	for i in scored_route.size()-1: length += scored_route[i].distance_to(scored_route[i+1])
	plan_timeout = length/actor.config.bot_speed*1.8+6
	has_plan = true
	tactical_action = "expand"
	planner_state = PlannerState.APPROACH
	elapsed = 0
	stuck = 0
	_clear_search()

func _clear_search() -> void:
	if planning_owner != null and is_instance_valid(planning_owner) and planning_team >= 0: planning_owner.cancel_preview(planning_team)
	pending_preview = null
	if recovery_preview != null: recovery_preview.cancel()
	recovery_preview = null
	proposals.clear()
	frontier_work.clear()
	scored_route.clear()
	scored_value = 0
	preview_checks = 0
	frontier_cursor = 0
	search_started = false

func note_capture(gain: float, territory: TerritoryManager) -> void:
	interrupted_route.clear()
	if not has_plan: return
	if gain > maxf(0.0002,expected_fraction*0.2):
		completed_captures += 1
		failures = maxi(0,failures-1)
	else: blocked.append({"point":plan_origin,"direction":plan_direction,"life":15.0})
	has_plan = false
	waypoints.clear()
	_clear_search()
	elapsed = 0
	stuck = 0
	wait = 0.1

func _safe_return(actor: ConquerCharacter, territory: TerritoryManager, map: CountryMap, fallback: Vector2) -> Array[Vector2]:
	var choices: Array[Vector2] = [fallback]
	if territory.owned(actor.team,planned_return): choices.append(planned_return)
	var frontier := territory.frontiers(actor.team).duplicate()
	frontier.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.home.distance_squared_to(actor.position) < b.home.distance_squared_to(actor.position))
	for i in mini(6,frontier.size()): choices.append(frontier[i].home)
	var best: float = INF
	var result: Array[Vector2] = []
	for point in choices:
		if not ShoreIndex.segment_inside(map.outline,actor.position,point): continue
		var route := actor.trail.points.duplicate()
		route.append(actor.position)
		route.append(point)
		var distance := actor.position.distance_to(point)
		# A different corridor wins at similar travel time; survival remains
		# more important than overlap during a genuine interception threat.
		var score := distance*(1+overlap_ratio(route)*0.5)
		if score < best:
			best = score
			result = [point]
	if result.is_empty(): result.assign(Array(map.route(actor.position,fallback)))
	return result

func _reposition(actor: ConquerCharacter, territory: TerritoryManager, map: CountryMap) -> void:
	var best: float = INF
	var target := actor.position
	var rival := _hunt_target(actor,territory)
	for item in territory.frontiers(actor.team):
		var distance: float = actor.position.distance_to(item.home)
		var score: float = distance*0.4 + item.home.distance_to(rival.position) if rival != null else distance
		if distance < 25 or score >= best: continue
		var inside: bool = true
		for i in 9:
			if not territory.owned(actor.team,actor.position.lerp(item.home,float(i)/8)): inside = false
		if inside:
			best = score
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
