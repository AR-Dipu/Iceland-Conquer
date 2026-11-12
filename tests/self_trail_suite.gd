extends SceneTree
func _initialize() -> void:
	var trail := ConquerTrail.new()
	trail.points = PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)])
	assert(trail.self_hit_fraction(Vector2(0, 100), Vector2(50, -100)) < 1.0)
	assert(trail.self_hit_fraction(Vector2(0, 100), Vector2(-50, 100)) == INF)
	assert(trail.self_hit_fraction(Vector2(-500, 50), Vector2(500, 50)) < 1.0)
	trail.clear()
	assert(trail.self_hit_fraction(Vector2(0, 100), Vector2(50, -100)) == INF)
	trail.free()
	print("RESULT 4 self-trail checks passed")
	quit()
