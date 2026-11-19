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
var mesh_hashes: Dictionary = {}
var frontier_hashes: Dictionary = {}
var boundary_cache: Dictionary = {}
var home_cache: Dictionary = {}
var planning_budget: int = -1
var planning_queue: Array[int] = []
var planning_epoch: int = 0
var planning_waiting: Dictionary = {}
var preview_jobs: Dictionary = {}
var preview_round: int = 0
var planning_deadline: int = 0
var planning_spent_usec: int = 0
var legacy_planning_budget: bool = false # Frozen 0.1.10 benchmark adapter only.
var capture_effects: Node2D

func begin_planning_frame() -> void:
	planning_deadline = Time.get_ticks_usec()+2000
	planning_spent_usec = 0
	planning_budget = 1
	planning_epoch += 1
	planning_queue = planning_queue.filter(func(team: int) -> bool: return planning_waiting.get(team,-10) >= planning_epoch-2)
	for team in preview_jobs.keys():
		var job: CapturePreviewJob = preview_jobs[team]
		if team >= regions.size() or job.round_token != preview_round or job.owner_hash != hash(regions[team]) or (team < nearby_actors.size() and not nearby_actors[team].active):
			cancel_preview(team)
			continue
		if not job.done:
			var began := WorkMetrics.start()
			var work_start := Time.get_ticks_usec()
			job.step(planning_deadline)
			planning_spent_usec += Time.get_ticks_usec()-work_start
			WorkMetrics.finish("planning_preview_slice",began)
			# Rotate fairly; one exact job is advanced per physics frame.
			preview_jobs.erase(team)
			preview_jobs[team] = job
			break

func start_preview(team: int, path: PackedVector2Array) -> CapturePreviewJob:
	cancel_preview(team)
	var bridge := path.size() >= 2 and _different_components(team,path[0],path[-1])
	var job := CapturePreviewJob.new(regions[team],island,path,bridge,preview_round)
	preview_jobs[team] = job
	return job

func cancel_preview(team: int) -> void:
	if preview_jobs.has(team):
		preview_jobs[team].cancel()
		preview_jobs.erase(team)

func request_planning(team: int) -> bool:
	if planning_budget < 0: return true # Standalone pure simulations.
	planning_waiting[team] = planning_epoch
	if not planning_queue.has(team): planning_queue.append(team)
	if planning_budget == 0 or planning_queue[0] != team or (not legacy_planning_budget and planning_spent_usec >= 2000): return false
	planning_queue.pop_front()
	planning_budget -= 1
	return true

func _exit_tree() -> void:
	for team in preview_jobs.keys(): cancel_preview(team)

func boundary_segments(team: int, a: Vector2, b: Vector2) -> Array:
	var cached: Dictionary = boundary_cache.get(team,{})
	if cached.get("revision",-1) != revision:
		var fingerprint: int = hash(regions[team])
		if cached.get("hash",-1) != fingerprint:
			cached = {"hash":fingerprint,"cells":{}}
			for p in regions[team]:
				for i in p.size():
					var edge := PackedVector2Array([p[i],p[(i+1)%p.size()]])
					var lo := Vector2i(floori(minf(edge[0].x,edge[1].x)/128),floori(minf(edge[0].y,edge[1].y)/128))
					var hi := Vector2i(floori(maxf(edge[0].x,edge[1].x)/128),floori(maxf(edge[0].y,edge[1].y)/128))
					for x in range(lo.x,hi.x+1):
						for y in range(lo.y,hi.y+1):
							var key := Vector2i(x,y)
							if not cached.cells.has(key): cached.cells[key] = []
							cached.cells[key].append(edge)
		cached["revision"] = revision
		boundary_cache[team] = cached
	var found: Dictionary = {}
	var lo := Vector2i(floori(minf(a.x,b.x)/128),floori(minf(a.y,b.y)/128))
	var hi := Vector2i(floori(maxf(a.x,b.x)/128),floori(maxf(a.y,b.y)/128))
	for x in range(lo.x,hi.x+1):
		for y in range(lo.y,hi.y+1):
			for edge in cached.cells.get(Vector2i(x,y),[]): found[edge] = true
	return found.keys()

func mesh_snapshot() -> Array:
	if mesh_revision == revision: return mesh_teams
	var began := WorkMetrics.start()
	mesh_teams.resize(regions.size())
	for team in regions.size():
		var fingerprint: int = hash(regions[team])
		if mesh_hashes.get(team,-1) == fingerprint: continue
		mesh_hashes[team] = fingerprint
		var pieces: Array = []
		var edges := PackedVector2Array()
		var smooth: Array[PackedVector2Array] = []
		for p in regions[team]:
			var indices := Geometry2D.triangulate_polygon(p)
			var colors := PackedColorArray()
			var bounds := IslandGeometry.bounds(island)
			var color: Color = config.team_colors[team]
			for vertex in p: colors.append(color.lightened(clampf((bounds.end.y-vertex.y)/maxf(1,bounds.size.y),0,1)*0.15))
			var mesh := ArrayMesh.new()
			if not indices.is_empty():
				var arrays: Array = []
				arrays.resize(Mesh.ARRAY_MAX)
				arrays[Mesh.ARRAY_VERTEX] = p
				arrays[Mesh.ARRAY_INDEX] = indices
				arrays[Mesh.ARRAY_COLOR] = colors
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			pieces.append({"polygon":p,"indices":indices,"mesh":mesh})
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
		mesh_teams[team] = {"pieces":pieces,"edges":edges}
		organic_cache[team] = smooth
	mesh_revision = revision
	WorkMetrics.finish("mesh_upload",began)
	return mesh_teams

func frontiers(team: int) -> Array:
	var fingerprint: int = hash(regions[team])
	if frontier_hashes.get(team,-1) != fingerprint:
		frontier_hashes[team] = fingerprint
		analysis_cache.erase(team)
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
	var errors_before: int = IslandGeometry.subtraction_errors
	var topology := CaptureTopology.enclosed(regions[team],trail)
	if not topology.ok: return {"ok":false,"pieces":[],"area":0.0}
	# Only a completed bridge between disconnected owned components earns a
	# ribbon. Elimination itself never adds a connection or fills the gap.
	if trail.size() >= 2 and _different_components(team,trail[0],trail[-1]):
		topology.faces.append_array(Geometry2D.offset_polyline(trail,3.75,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND))
	var pieces: Array[PackedVector2Array] = []
	var total: float = 0
	for face in topology.faces:
		for clipped in Geometry2D.intersect_polygons(face,island):
			var uncovered: Array[PackedVector2Array] = [clipped]
			for existing in regions[team]:
				var remaining: Array[PackedVector2Array] = []
				for piece in uncovered: remaining.append_array(IslandGeometry.subtract(piece,existing))
				uncovered = remaining
			# Faces and ribbons can overlap; count and transfer each point once.
			for existing in pieces:
				var remaining: Array[PackedVector2Array] = []
				for piece in uncovered: remaining.append_array(IslandGeometry.subtract(piece,existing))
				uncovered = remaining
			for piece in uncovered:
				var clean := IslandGeometry.clean_polygon(piece)
				if IslandGeometry.area(clean) < 8: continue
				if not IslandGeometry.simple(clean): return {"ok":false,"pieces":[],"area":0.0}
				pieces.append(clean)
				total += IslandGeometry.area(clean)
	if IslandGeometry.subtraction_errors != errors_before: return {"ok":false,"pieces":[],"area":0.0}
	return {"ok":true,"pieces":pieces,"area":total}

func closed_excursion(team: int, route: PackedVector2Array) -> PackedVector2Array:
	# Evaluate the same FIRST home entry that the movement coordinator closes.
	# Scoring the rest of an imagined loop overestimated routes crossing home.
	var result := PackedVector2Array()
	for i in route.size()-1:
		var a := route[i]
		var b := route[i+1]
		var length := a.distance_to(b)
		if length < 0.001: continue
		var cuts: Array[float] = [0,1]
		for edge in boundary_segments(team,a,b):
			var hit: Variant = Geometry2D.segment_intersects_segment(a,b,edge[0],edge[1])
			if hit != null: cuts.append(clampf(a.distance_to(hit)/length,0,1))
		cuts.sort()
		for j in cuts.size()-1:
			if cuts[j+1]-cuts[j] < 0.00001: continue
			var start := a.lerp(b,cuts[j])
			var finish := a.lerp(b,cuts[j+1])
			if owned(team,(start+finish)*0.5):
				if result.size() >= 2:
					if result[-1].distance_to(start) > 0.001: result.append(start)
					result.append(finish)
					return result
			else:
				if result.is_empty() or result[-1].distance_to(start) > 0.001: result.append(start)
				result.append(finish)
	return PackedVector2Array()

func open_reach(team: int, home: Vector2, direction: Vector2, maximum: float) -> float:
	var finish := home+direction*maximum
	var cuts: Array[float] = [0,maximum]
	for edge in boundary_segments(team,home,finish):
		var hit: Variant = Geometry2D.segment_intersects_segment(home,finish,edge[0],edge[1])
		if hit != null: cuts.append(home.distance_to(hit))
	cuts.sort()
	var outside: bool = false
	for i in cuts.size()-1:
		if cuts[i+1]-cuts[i] < 0.001: continue
		var mid := home+direction*((cuts[i]+cuts[i+1])*0.5)
		if owned(team,mid):
			if outside: return cuts[i]
		else: outside = true
	return maximum

func _different_components(team: int, start: Vector2, finish: Vector2) -> bool:
	var reached: Dictionary = {}
	var targets: Array[int] = []
	for i in regions[team].size():
		var p: PackedVector2Array = regions[team][i]
		if Geometry2D.is_point_in_polygon(start,p) or start.distance_to(IslandGeometry.nearest(p,start).point) < 0.02: reached[i] = true
		if Geometry2D.is_point_in_polygon(finish,p) or finish.distance_to(IslandGeometry.nearest(p,finish).point) < 0.02: targets.append(i)
		if reached.has(i) and targets.has(i): return false
	if reached.is_empty() or targets.is_empty(): return false
	var pending: Array = reached.keys()
	while not pending.is_empty():
		var i: int = pending.pop_back()
		if targets.has(i): return false
		for j in regions[team].size():
			if reached.has(j): continue
			var touching: bool = false
			for point in regions[team][i]:
				if Geometry2D.is_point_in_polygon(point,regions[team][j]) or point.distance_to(IslandGeometry.nearest(regions[team][j],point).point) < 0.02:
					touching = true
					break
			if touching:
				reached[j] = true
				pending.append(j)
	return true

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
	for team in preview_jobs.keys(): cancel_preview(team)
	preview_round += 1
	regions = initial.duplicate(true)
	_clear_flashes()
	if is_instance_valid(capture_effects): capture_effects.queue_redraw()
	planning_queue.clear()
	_update_fractions()

func owned(team: int, point: Vector2) -> bool:
	for p in regions[team]:
		if Geometry2D.is_point_in_polygon(point,p): return true
	return false

func safe_home(team: int, point: Vector2) -> Vector2:
	var fingerprint := hash(regions[team])
	if home_cache.get(team,{}).get("hash",-1) != fingerprint:
		var choices: Array[Vector2] = []
		for polygon in regions[team]:
			var center := IslandGeometry.interior_point(polygon)
			for i in range(0,polygon.size(),maxi(1,polygon.size()/12)):
				var candidate: Vector2 = polygon[i].lerp(center,0.08)
				if owned(team,candidate): choices.append(candidate)
		home_cache[team] = {"hash":fingerprint,"choices":choices}
	var best := point
	var distance: float = INF
	for candidate in home_cache[team].choices:
		if candidate.distance_squared_to(point) < distance:
			distance = candidate.distance_squared_to(point)
			best = candidate
	return best

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
	var began := WorkMetrics.start()
	var result := _capture_transaction(team,trail,departure)
	WorkMetrics.finish("capture_transaction",began)
	return result

func _capture_transaction(team: int, trail: PackedVector2Array, departure: PackedVector2Array) -> bool:
	last_capture_error = ""
	var preview := preview_capture(team,trail)
	if not preview.ok:
		last_capture_error = "Capture could not be resolved; territory preserved."
		return false
	if preview.area <= 0: return false
	var snapshot: Array = regions.duplicate(true)
	var errors_before: int = IslandGeometry.subtraction_errors
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
			if flashes.size() > 12:
				var old: Dictionary = flashes.pop_front()
				if is_instance_valid(old.get("node")): old.node.queue_free()
	regions[team] = IslandGeometry.merge_regions(typed(regions[team]))
	if IslandGeometry.subtraction_errors != errors_before:
		regions = snapshot
		_clear_flashes()
		if is_instance_valid(capture_effects): capture_effects.queue_redraw()
		last_capture_error = "Capture precision could not be resolved; territory preserved."
		return false
	for polys in regions:
		for p in polys:
			if not IslandGeometry.simple(p):
				regions = snapshot
				_clear_flashes()
				if is_instance_valid(capture_effects): capture_effects.queue_redraw()
				last_capture_error = "Capture validation failed; territory preserved."
				return false

	_update_fractions()
	if fractions[team] > before + 0.0001:
		captured.emit(team, fractions[team] - before, trail[-1])
		return true
	return false

func reset_team(team: int) -> void:
	var snapshot := regions.duplicate(true)
	var errors_before: int = IslandGeometry.subtraction_errors
	regions[team] = initial[team].duplicate(true)
	for p in regions[team]:
		_remove_from_others(team, p)
	if IslandGeometry.subtraction_errors != errors_before: regions = snapshot
	_update_fractions()

func _update_fractions() -> void:
	revision += 1
	for team in regions.size():
		var total: float = 0.0
		for p in regions[team]:
			total += IslandGeometry.area(p)
		fractions[team] = clampf(total / island_area, 0.0, 1.0)
	territory_changed.emit(fractions)
	queue_redraw()

func _process(delta: float) -> void:
	if flashes.is_empty():
		return
	if not is_instance_valid(capture_effects):
		capture_effects = Node2D.new()
		capture_effects.z_index = 1
		add_child(capture_effects)
	for flash in flashes:
		flash.life -= delta
		if flash.life <= 0:
			if is_instance_valid(flash.get("node")): flash.node.queue_free()
			continue
		if not flash.has("node"): _upload_effect(flash)
		flash.node.material.set_shader_parameter("progress",1-float(flash.life)/0.45)
	flashes = flashes.filter(func(f: Dictionary) -> bool: return f.life > 0.0)

func _clear_flashes() -> void:
	for flash in flashes:
		if is_instance_valid(flash.get("node")): flash.node.queue_free()
	flashes.clear()

func _upload_effect(flash: Dictionary) -> void:
	var began := WorkMetrics.start()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = flash.polygon
	arrays[Mesh.ARRAY_INDEX] = Geometry2D.triangulate_polygon(flash.polygon)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var instance := MeshInstance2D.new()
	instance.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/capture_reveal.gdshader")
	material.set_shader_parameter("tint",config.team_colors[flash.team].lightened(0.65))
	material.set_shader_parameter("origin",flash.origin)
	material.set_shader_parameter("radius",maxf(1,IslandGeometry.bounds(flash.polygon).size.length()))
	instance.material = material
	capture_effects.add_child(instance)
	flash.node = instance
	WorkMetrics.finish("effect_upload",began)

func _draw() -> void:
	if config == null:
		return
	var snapshot := mesh_snapshot()
	for team in regions.size():
		var color: Color = config.team_colors[team]
		for piece in snapshot[team].pieces:
			if not piece.indices.is_empty():
				draw_mesh(piece.mesh,null)
		# A clipped rounded overlay softens sharp capture corners without changing
		# authoritative territory or painting across a rival's boundary.
		for rounded in organic_cache.get(team,[]):
			draw_colored_polygon(rounded,Color(color.lightened(0.12),0.3))
		var edges: PackedVector2Array = snapshot[team].edges
		if not edges.is_empty():
			draw_multiline(edges,Color(color.lightened(0.45),0.08),8.0,true)
			draw_multiline(edges,Color(color.lightened(0.55),0.55),1.4,true)

