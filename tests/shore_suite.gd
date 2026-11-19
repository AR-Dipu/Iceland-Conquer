extends SceneTree
var checks: int = 0
func verify(value: bool,label: String) -> void:
	assert(value,label)
	checks += 1
func _initialize() -> void:
	var square := PackedVector2Array([Vector2(0,0),Vector2(100,0),Vector2(100,100),Vector2(0,100)])
	var slide := ShoreMotion.solve(Vector2(90,40),Vector2(100,40),0.5,square)
	verify(slide.position.x < 100 and slide.position.y > 59,"Diagonal movement slides along shore")
	verify(absf(slide.velocity.x) < 0.01 and slide.velocity.y > 39,"Tangent velocity preserved")
	verify(slide.path.size() >= 3,"Contact segments recorded")
	var corner := ShoreMotion.solve(Vector2(90,90),Vector2(100,100),1,square)
	verify(Geometry2D.is_point_in_polygon(corner.position,square),"Corner stays inside")
	var leave := ShoreMotion.solve(corner.position,Vector2(-100,-100),0.2,square)
	verify(leave.position.distance_to(corner.position) > 20,"Can leave corner immediately")
	var stop := ShoreMotion.solve(Vector2(20,20),Vector2.ZERO,1,square)
	verify(stop.position == Vector2(20,20),"Release stops")
	var bay := PackedVector2Array([Vector2(0,0),Vector2(100,0),Vector2(100,40),Vector2(40,40),Vector2(40,100),Vector2(0,100)])
	var swept := ShoreMotion.solve(Vector2(20,80),Vector2(500,-200),0.4,bay)
	for i in swept.path.size()-1:
		verify(IslandGeometry.segment_inside(bay,swept.path[i],swept.path[i+1]),"Swept path never shortcuts across water")
	var trail := ConquerTrail.new()
	trail.points = PackedVector2Array([Vector2(95,55),Vector2(100,55)])
	var actual_hit := false
	for i in slide.path.size()-1: actual_hit = actual_hit or trail.hits(slide.path[i],slide.path[i+1],0.5)
	verify(actual_hit,"Enemy trail detected on slide segment")
	trail.free()
	print("RESULT ",checks," shore checks passed")
	quit()
