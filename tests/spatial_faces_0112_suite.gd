extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func reference(poly: PackedVector2Array, depth: int = 0) -> Array:
	if depth > 64 or poly.size() < 3: return []
	for i in poly.size():
		for j in range(i+2,poly.size()):
			if i == 0 and j == poly.size()-1: continue
			var hit: Variant = Geometry2D.segment_intersects_segment(poly[i],poly[(i+1)%poly.size()],poly[j],poly[(j+1)%poly.size()])
			if hit == null: continue
			var first := PackedVector2Array([hit])
			for k in range(i+1,j+1):
				if first[-1].distance_to(poly[k]) > 0.01: first.append(poly[k])
			var second := PackedVector2Array([hit])
			for k in range(j+1,poly.size()):
				if second[-1].distance_to(poly[k]) > 0.01: second.append(poly[k])
			for k in range(i+1):
				if second[-1].distance_to(poly[k]) > 0.01: second.append(poly[k])
			if first.size()>1 and first[0].distance_to(first[-1])<0.01: first.remove_at(first.size()-1)
			if second.size()>1 and second[0].distance_to(second[-1])<0.01: second.remove_at(second.size()-1)
			var result := reference(first,depth+1)
			result.append_array(reference(second,depth+1))
			return result
	if not IslandGeometry.simple(poly): return []
	var result := poly.duplicate()
	if Geometry2D.is_polygon_clockwise(result): result.reverse()
	return [result]
func run() -> void:
	seed(1213)
	for case in 100:
		var polygon := PackedVector2Array()
		for i in 12:
			polygon.append(Vector2(randf_range(-2000,2000),randf_range(-2000,2000)))
		if case%4 == 0: polygon[5] = polygon[0]
		var expected := reference(polygon)
		var actual := IslandGeometry.split_faces(polygon)
		assert(actual.size() == expected.size())
		for i in actual.size(): assert(actual[i] == expected[i])
	print("RESULT 100 spatial face results exactly match original all-pairs geometry")
	var frozen = load("res://tests/fixtures/capture_topology_0111.gd")
	for case in 100:
		var owned: Array = [IslandGeometry.blob(Vector2.ZERO,Vector2(100,80),0,32),IslandGeometry.blob(Vector2(600,0),Vector2(60,70),0,24)]
		var path := PackedVector2Array([Vector2(100,0)])
		for i in 8: path.append(Vector2(randf_range(-300,900),randf_range(-400,400)))
		path.append(Vector2(-100,0) if case%2 == 0 else Vector2(540,0))
		if case%4 == 0: path[4] = path[2]
		if case%5 == 0: path[3] = path[2].lerp(path[4],0.5)
		var expected: Dictionary = frozen.enclosed(owned,path)
		var actual := CaptureTopology.enclosed(owned,path)
		if actual.ok != expected.ok or actual.faces != expected.faces:
			print("TOPOLOGY DIFFERENCE ",case," ",JSON.stringify({"path":path,"actual":actual,"expected":expected}))
			quit(1)
		assert(actual.ok == expected.ok and actual.faces == expected.faces)
	print("RESULT 100 topology results exactly match frozen 0.1.11 intersections")
	quit()
