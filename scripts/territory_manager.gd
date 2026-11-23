class_name TerritoryManager
extends Node2D

signal territory_changed(fractions: Array[float])
signal mesh_published
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
var tactical_epoch: int = -1
var tactical_states: Dictionary = {}
var preview_cache: Dictionary = {}

func tactical_state(actor: ConquerCharacter, country: CountryMap) -> Dictionary:
	if tactical_epoch != planning_epoch:
		tactical_epoch = planning_epoch
		tactical_states.clear()
	var key := hash([actor.position,actor.velocity,regions[actor.team]])
	if tactical_states.has(actor.team) and tactical_states[actor.team].key == key: return tactical_states[actor.team]
	var home := safe_home(actor.team,actor.position)
	var length: float = 0 if owned(actor.team,actor.position) else TacticalContext.route_distance(country,actor.position,home)
	if regions[actor.team].is_empty(): length = INF
	var state := {"home":home,"return_eta":TacticalContext.actor_eta(actor,length,actor.position.direction_to(home)),"key":key}
	tactical_states[actor.team] = state
	return state

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
			if job.done and job.result.get("ok",false): _remember_preview(team,job.path,job.result)
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

var staged_meshes: Array = []
var staged_organic: Dictionary = {}
var staged_hashes: Dictionary = {}
var mesh_jobs: Array[int] = []
var mesh_work: Dictionary = {}
var effect_pool: Array[MeshInstance2D] = []
var capture_frames: Array[int] = []
var visible_delays: Array[int] = []
var staged_revision: int = -1
var fill_cache: Dictionary = {}
var last_enclosed_faces: Array = []
var last_enclosed_pieces: Array = []
var last_enclosed_previous: Array = []

func newly_encircles(point: Vector2) -> bool:
	for polygon in last_enclosed_previous:
		if Geometry2D.is_point_in_polygon(point,polygon): return false
	for face in last_enclosed_faces:
		if not Geometry2D.is_point_in_polygon(point,face): continue
		if point.distance_squared_to(IslandGeometry.nearest(face,point).point) <= 0.0001: continue
		for piece in last_enclosed_pieces:
			if Geometry2D.is_point_in_polygon(point,piece): return true
	return false

func _start_mesh_build() -> void:
	staged_revision = revision
	staged_meshes = mesh_teams.duplicate()
	staged_meshes.resize(regions.size())
	staged_organic = organic_cache.duplicate()
	staged_hashes = mesh_hashes.duplicate()
	mesh_jobs.clear()
	mesh_work.clear()
	for team in regions.size():
		if staged_hashes.get(team,-1) != hash(regions[team]): mesh_jobs.append(team)

func _step_team_mesh(team: int) -> bool:
	if mesh_work.is_empty():
		var bounds: Array[Rect2] = []
		for polygon in regions[team]: bounds.append(IslandGeometry.bounds(polygon).grow(0.51))
		mesh_work = {"polygon":0,"edge":0,"pieces":[],"edges":PackedVector2Array(),"bounds":bounds}
	var index: int = mesh_work.polygon
	if index >= regions[team].size():
		staged_meshes[team] = {"pieces":mesh_work.pieces,"edges":mesh_work.edges}
		staged_hashes[team] = hash(regions[team])
		mesh_work.clear()
		return true
	var polygon: PackedVector2Array = regions[team][index]
	var offset: int = mesh_work.edge
	if offset == 0:
		var indices := IslandGeometry.triangles_cached(polygon)
		mesh_work.pieces.append({"polygon":polygon,"indices":indices,"mesh":_fill_mesh(polygon,indices)})
	var edges: PackedVector2Array = mesh_work.edges
	var stop := mini(offset+32,polygon.size())
	for i in range(offset,stop):
		var a := polygon[i]
		var b := polygon[(i+1)%polygon.size()]
		var mid := (a+b)*0.5
		var shared := false
		for neighbor in mesh_work.bounds.size():
			if neighbor != index and mesh_work.bounds[neighbor].has_point(mid):
				var normal := (b-a).orthogonal().normalized()*0.5
				shared = owned(team,mid+normal) and owned(team,mid-normal)
				break
		if not shared:
			edges.append(a)
			edges.append(b)
	mesh_work.edges = edges
	mesh_work.edge = 0 if stop == polygon.size() else stop
	if stop == polygon.size(): mesh_work.polygon += 1
	return false

func _fill_mesh(polygon: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var key := hash(polygon)
	var cached: Dictionary = fill_cache.get(key,{})
	if cached.get("polygon") == polygon: return cached.mesh
	var mesh := CountryPresentation._mesh(polygon,indices) if not indices.is_empty() else ArrayMesh.new()
	if fill_cache.size() >= 128: fill_cache.erase(fill_cache.keys()[0])
	fill_cache[key] = {"polygon":polygon.duplicate(),"mesh":mesh}
	return mesh

func _publish_meshes() -> void:
	mesh_teams = staged_meshes
	organic_cache = staged_organic
	mesh_hashes = staged_hashes
	mesh_revision = staged_revision
	queue_redraw()
	mesh_published.emit()
	if WorkMetrics.enabled and not capture_frames.is_empty():
		var submitted := capture_frames.duplicate()
		capture_frames.clear()
		RenderingServer.frame_post_draw.connect(func() -> void:
			for frame_id in submitted:
				visible_delays.append(maxi(1,Engine.get_frames_drawn()-frame_id+1))
		,CONNECT_ONE_SHOT)

func mesh_snapshot() -> Array:
	if mesh_revision == revision: return mesh_teams
	var began := WorkMetrics.start()
	if staged_revision != revision: _start_mesh_build()
	while not mesh_jobs.is_empty():
		if _step_team_mesh(mesh_jobs[0]): mesh_jobs.pop_front()
	_publish_meshes()
	WorkMetrics.finish("mesh_upload",began)
	return mesh_teams

func render_snapshot() -> Array:
	if mesh_teams.is_empty() or not is_inside_tree(): return mesh_snapshot()
	return mesh_teams

func _pump_meshes() -> void:
	if mesh_revision == revision: return
	if staged_revision != revision: _start_mesh_build()
	var began := WorkMetrics.start()
	var deadline := Time.get_ticks_usec()+2000
	while not mesh_jobs.is_empty():
		if _step_team_mesh(mesh_jobs[0]): mesh_jobs.pop_front()
		if Time.get_ticks_usec() >= deadline: break
	if mesh_jobs.is_empty(): _publish_meshes()
	WorkMetrics.finish("mesh_upload",began)

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
	var key := hash([team,regions[team],island,trail])
	if preview_cache.has(key):
		var value: Dictionary = preview_cache[key]
		if value.path == trail and value.owned == regions[team] and value.coast == island: return value.result.duplicate(true)
	var result := _preview_capture_exact(team,trail)
	if result.ok: _remember_preview(team,trail,result)
	return result

func _remember_preview(team: int, trail: PackedVector2Array, result: Dictionary) -> void:
	var key := hash([team,regions[team],island,trail])
	if preview_cache.size() >= 8: preview_cache.erase(preview_cache.keys()[0])
	preview_cache[key] = {"path":trail.duplicate(),"owned":regions[team].duplicate(true),"coast":island.duplicate(),"result":result.duplicate(true)}

func _preview_capture_exact(team: int, trail: PackedVector2Array, prepared: Dictionary = {}) -> Dictionary:
	var errors_before: int = IslandGeometry.subtraction_errors
	var topology_began := WorkMetrics.start()
	var topology := CaptureTopology.enclosed(regions[team],trail) if prepared.is_empty() else CaptureTopology.enclosed_prepared(prepared)
	WorkMetrics.finish("capture_topology",topology_began)
	if not topology.ok: return {"ok":false,"pieces":[],"area":0.0}
	var enclosed_faces: Array = topology.faces.duplicate()
	# Only a completed bridge between disconnected owned components earns a
	# ribbon. Elimination itself never adds a connection or fills the gap.
	if trail.size() >= 2 and _different_components(team,trail[0],trail[-1]):
		topology.faces.append_array(Geometry2D.offset_polyline(trail,3.75,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND))
	var pieces: Array[PackedVector2Array] = []
	var enclosed_count := 0
	var total: float = 0
	for face_index in topology.faces.size():
		var face: PackedVector2Array = topology.faces[face_index]
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
				if face_index < enclosed_faces.size(): enclosed_count += 1
				total += IslandGeometry.area(clean)
	if IslandGeometry.subtraction_errors != errors_before: return {"ok":false,"pieces":[],"area":0.0}
	return {"ok":true,"pieces":pieces,"area":total,"enclosed_faces":enclosed_faces,"enclosed_count":enclosed_count}

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
	if capture_effects == null: _prepare_effect_pool()
	reset_all()

func typed(polys: Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for p in polys:
		result.append(p)
	return result

func reset_all() -> void:
	preview_cache.clear()
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

func capture(team: int, trail: PackedVector2Array, departure: PackedVector2Array, prepared: Dictionary = {}) -> bool:
	var began := WorkMetrics.start()
	var result := _capture_transaction(team,trail,departure,prepared)
	WorkMetrics.finish("capture_transaction",began)
	return result

func _capture_transaction(team: int, trail: PackedVector2Array, departure: PackedVector2Array, prepared: Dictionary = {}) -> bool:
	last_enclosed_faces = []
	last_enclosed_pieces = []
	last_enclosed_previous = []
	last_capture_error = ""
	var preview := preview_capture(team,trail) if prepared.is_empty() else _preview_capture_exact(team,trail,prepared)
	if not preview.ok:
		last_capture_error = "Capture could not be resolved; territory preserved."
		return false
	if preview.area <= 0: return false
	var snapshot: Array = regions.duplicate(true)
	var errors_before: int = IslandGeometry.subtraction_errors
	var before: float = fractions[team]
	var additions: Array = preview.pieces
	var enclosed_additions: Array = []
	for index in additions.size():
		var addition := IslandGeometry.clean_polygon(additions[index])
		if not IslandGeometry.simple(addition): continue
		if index < int(preview.get("enclosed_count",0)): enclosed_additions.append(addition)
		# preview_capture already subtracts current ownership and prior additions.
		# No mutation/yield occurs between preview and this transaction.
		_remove_from_others(team,addition)
		regions[team].append(addition)
		flashes.append({"polygon":addition,"life":0.45,"team":team,"origin":trail[-1]})
		if flashes.size() > 12:
			var old: Dictionary = flashes.pop_front()
			_release_effect(old)
	var merge_began := WorkMetrics.start()
	regions[team] = IslandGeometry.merge_regions(typed(regions[team]))
	WorkMetrics.finish("capture_merge",merge_began)
	if IslandGeometry.subtraction_errors != errors_before:
		regions = snapshot
		_clear_flashes()
		if is_instance_valid(capture_effects): capture_effects.queue_redraw()
		last_capture_error = "Capture precision could not be resolved; territory preserved."
		return false
	for other in regions.size():
		# Unchanged teams were validated in the previous committed snapshot.
		if regions[other] == snapshot[other]: continue
		for p in regions[other]:
			if not IslandGeometry.simple(p):
				regions = snapshot
				_clear_flashes()
				if is_instance_valid(capture_effects): capture_effects.queue_redraw()
				last_capture_error = "Capture validation failed; territory preserved."
				return false

	_update_fractions()
	if fractions[team] > before + 0.0001:
		if WorkMetrics.enabled and DisplayServer.get_name() != "headless": capture_frames.append(Engine.get_frames_drawn())
		last_enclosed_faces = preview.get("enclosed_faces", [])
		last_enclosed_pieces = enclosed_additions
		last_enclosed_previous = snapshot[team]
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
	_pump_meshes()
	if not get_parent().can_process(): return
	if mesh_revision != revision: return
	if flashes.is_empty():
		return
	var started := 0
	for flash in flashes:
		if not flash.has("node"):
			if started >= 2 or effect_pool.is_empty(): continue
			_upload_effect(flash)
			started += 1
		flash.life -= delta
		if flash.life <= 0:
			_release_effect(flash)
			continue
		flash.node.material.set_shader_parameter("progress",1-float(flash.life)/0.45)
	flashes = flashes.filter(func(f: Dictionary) -> bool: return f.life > 0.0)

func _clear_flashes() -> void:
	for flash in flashes: _release_effect(flash)
	flashes.clear()

func _release_effect(flash: Dictionary) -> void:
	if not is_instance_valid(flash.get("node")): return
	var instance: MeshInstance2D = flash.node
	instance.hide()
	instance.mesh = null
	effect_pool.append(instance)
	flash.erase("node")

func _prepare_effect_pool() -> void:
	capture_effects = Node2D.new()
	capture_effects.z_index = 1
	add_child(capture_effects)
	for i in 6:
		var instance := MeshInstance2D.new()
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/shaders/capture_reveal.gdshader")
		instance.material = material
		instance.hide()
		capture_effects.add_child(instance)
		effect_pool.append(instance)

func _upload_effect(flash: Dictionary) -> void:
	var began := WorkMetrics.start()
	var instance: MeshInstance2D = effect_pool.pop_back()
	instance.mesh = _fill_mesh(flash.polygon,IslandGeometry.triangles_cached(flash.polygon))
	var material: ShaderMaterial = instance.material
	material.set_shader_parameter("tint",config.team_colors[flash.team].lightened(0.65))
	material.set_shader_parameter("origin",flash.origin)
	material.set_shader_parameter("radius",maxf(1,IslandGeometry.bounds(flash.polygon).size.length()))
	instance.show()
	flash.node = instance
	WorkMetrics.finish("effect_upload",began)

func _draw() -> void:
	if config == null:
		return
	var snapshot := render_snapshot()
	for team in snapshot.size():
		var color: Color = config.team_colors[team]
		for piece in snapshot[team].pieces:
			if not piece.indices.is_empty():
				draw_mesh(piece.mesh,null,Transform2D.IDENTITY,Color(color,0.63))
		var edges: PackedVector2Array = snapshot[team].edges
		if not edges.is_empty():
			draw_multiline(edges,Color(color.darkened(0.5),0.82),2.8,true)
			draw_multiline(edges,Color(color.lightened(0.30),0.75),1.0,true)

