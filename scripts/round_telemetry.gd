class_name RoundTelemetry
extends RefCounted
var enabled: bool = false
var events: Array[Dictionary] = []
var planning_usec: int = 0
var reverse: Dictionary = {"expand":0.0,"attack":0.0,"defend":0.0,"recover":0.0}
var distance: Dictionary = {"expand":0.0,"attack":0.0,"defend":0.0,"recover":0.0}
func reset() -> void:
	events.clear()
	planning_usec = 0
	for key in reverse:
		reverse[key] = 0.0
		distance[key] = 0.0
func motion(actor: ConquerCharacter, action: String) -> void:
	if not enabled or actor.team == 0 or actor.trail.points.size() < 2: return
	var key := action if reverse.has(action) else "recover"
	for i in actor.movement_path.size()-1:
		var a := actor.movement_path[i]
		var b := actor.movement_path[i+1]
		var length := a.distance_to(b)
		if length < 0.001: continue
		distance[key] += length
		for index in actor.trail.query_segments(a,b,10):
			var p := actor.trail.points[index]
			var q := actor.trail.points[index+1]
			if a.direction_to(b).dot(p.direction_to(q)) < -0.8 and IslandGeometry.segment_distance(a,b,p,q) < 10:
				reverse[key] += length
				break
func record(kind: String, values: Dictionary) -> void:
	if not enabled: return
	var event := values.duplicate(true)
	event["kind"] = kind
	events.append(event)
func cuts_by_bots(method: String = "trail") -> int:
	var count: int = 0
	for event in events:
		if event.kind == "elimination" and event.attacker > 0 and event.credited and event.get("method","trail") == method: count += 1
	return count
