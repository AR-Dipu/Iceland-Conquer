class_name ShoreMotion
extends RefCounted
const MARGIN: float = 0.35

static func solve(start: Vector2, velocity: Vector2, delta: float, island: PackedVector2Array) -> Dictionary:
	var steps: int = clampi(ceili(velocity.length()*delta/12.0),1,32)
	var point := start
	var current_velocity := velocity
	var path := PackedVector2Array([start])
	for i in steps:
		var step := _slide(point,current_velocity,delta/steps,island)
		point = step.position
		current_velocity = step.velocity
		for p in step.path:
			if path[-1].distance_to(p) > 0.0001: path.append(p)
	return {"position":point,"velocity":current_velocity,"path":path}

static func _slide(start: Vector2, velocity: Vector2, delta: float, island: PackedVector2Array) -> Dictionary:
	var point := start
	var remaining: Vector2 = velocity * delta
	var result_velocity := velocity
	var path := PackedVector2Array([start])
	for iteration in 5:
		if remaining.length_squared() < 0.000001: break
		var fraction: float = INF
		var edge_index: int = -1
		for i in island.size():
			var a: Vector2 = island[i]
			var b: Vector2 = island[(i+1)%island.size()]
			var hit: Variant = Geometry2D.segment_intersects_segment(point,point+remaining,a,b)
			if hit == null: continue
			var t: float = (hit-point).dot(remaining)/remaining.length_squared()
			if t >= -0.00001 and t < fraction:
				var tangent := a.direction_to(b)
				var inward := Vector2(-tangent.y,tangent.x)
				if Geometry2D.is_polygon_clockwise(island): inward = -inward
				if remaining.dot(inward) < -0.00001:
					fraction = maxf(0,t)
					edge_index = i
		if edge_index < 0:
			var target := point+remaining
			if Geometry2D.is_point_in_polygon(target,island):
				point = target
				path.append(point)
			else:
				# Numerical corner contact: stop locally, never relocate across land.
				result_velocity = Vector2.ZERO
			break
		var edge_a: Vector2 = island[edge_index]
		var edge_b: Vector2 = island[(edge_index+1)%island.size()]
		var tangent := edge_a.direction_to(edge_b)
		var inward := Vector2(-tangent.y,tangent.x)
		if Geometry2D.is_polygon_clockwise(island): inward = -inward
		var contact: Vector2 = point+remaining*fraction
		var safe := contact+inward*0.025
		if not Geometry2D.is_point_in_polygon(safe,island):
			safe = point.lerp(contact,maxf(0,1-MARGIN/maxf(point.distance_to(contact),MARGIN)))
		if point.distance_to(safe) > 0.0001: path.append(safe)
		point = safe
		remaining *= 1-fraction
		remaining -= inward*minf(0,remaining.dot(inward))
		result_velocity -= inward*minf(0,result_velocity.dot(inward))
	if path[-1].distance_to(point) > 0.0001: path.append(point)
	return {"position":point,"velocity":result_velocity,"path":path}
