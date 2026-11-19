class_name CapturePreviewJob
extends RefCounted
signal continued
var topology: CaptureTopologyJob
var owned: Array
var island: PackedVector2Array
var path: PackedVector2Array
var ribbon: bool
var owner_hash: int
var round_token: int
var done: bool = false
var canceled: bool = false
var clipping: bool = false
var deadline: int
var result: Dictionary = {}
var cpu_usec: int = 0
func _init(polygons: Array, coast: PackedVector2Array, trail: PackedVector2Array, connection: bool, token: int) -> void:
	owned = polygons.duplicate(true)
	island = coast.duplicate()
	path = trail.duplicate()
	ribbon = connection
	owner_hash = hash(polygons)
	round_token = token
	topology = CaptureTopologyJob.new(owned,path)
func step(until_usec: int) -> bool:
	if done: return true
	var began := Time.get_ticks_usec()
	deadline = until_usec
	if not topology.done: topology.step(deadline)
	if topology.done and not done and Time.get_ticks_usec() < deadline:
		if not topology.result.ok: _finish({"ok":false,"pieces":[],"area":0.0})
		elif clipping: continued.emit()
		else:
			clipping = true
			_clip()
	cpu_usec += Time.get_ticks_usec()-began
	return done
func cancel() -> void:
	canceled = true
	topology.cancel()
	if clipping and not done: continued.emit()
	if not done: _finish({"ok":false,"pieces":[],"area":0.0})
func _finish(value: Dictionary) -> void:
	result = value
	done = true
func _clip() -> void:
	var faces: Array = topology.result.faces.duplicate()
	if ribbon: faces.append_array(Geometry2D.offset_polyline(path,3.75,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND))
	var pieces: Array[PackedVector2Array] = []
	var total: float = 0
	for face in faces:
		if Time.get_ticks_usec() >= deadline: await continued
		if canceled: return
		for clipped in Geometry2D.intersect_polygons(face,island):
			var uncovered: Array[PackedVector2Array] = [clipped]
			var cutters: Array = owned.duplicate()
			cutters.append_array(pieces)
			for existing in cutters:
				if Time.get_ticks_usec() >= deadline: await continued
				if canceled: return
				var remaining: Array[PackedVector2Array] = []
				var errors := IslandGeometry.subtraction_errors
				for piece in uncovered: remaining.append_array(IslandGeometry.subtract(piece,existing))
				if IslandGeometry.subtraction_errors != errors:
					_finish({"ok":false,"pieces":[],"area":0.0})
					return
				uncovered = remaining
			for piece in uncovered:
				var clean := IslandGeometry.clean_polygon(piece)
				if IslandGeometry.area(clean) < 8: continue
				if not IslandGeometry.simple(clean):
					_finish({"ok":false,"pieces":[],"area":0.0})
					return
				pieces.append(clean)
				total += IslandGeometry.area(clean)
	_finish({"ok":true,"pieces":pieces,"area":total})
