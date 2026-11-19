extends SceneTree
func rect(x: float,y: float,w: float,h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x,y),Vector2(x+w,y),Vector2(x+w,y+h),Vector2(x,y+h)])
func _initialize() -> void:
	var owned: Array = [rect(20,20,60,60)]
	var path := PackedVector2Array([Vector2(70,30),Vector2(200,30),Vector2(200,150),Vector2(40,150),Vector2(40,70)])
	var job := CapturePreviewJob.new(owned,rect(0,0,300,300),path,false,1)
	for tick in 1000:
		if job.step(Time.get_ticks_usec()+200): break
	assert(job.done and job.result.ok and absf(job.result.area-17200)<1,"Resumable preview matches exact area")
	var canceled := CapturePreviewJob.new(owned,rect(0,0,300,300),path,false,1)
	canceled.step(Time.get_ticks_usec())
	canceled.cancel()
	assert(canceled.done and canceled.canceled and not canceled.result.ok)
	var tm := TerritoryManager.new()
	tm.regions = [owned]
	tm.island = rect(0,0,300,300)
	var stale := tm.start_preview(0,path)
	tm.regions[0] = []
	tm.begin_planning_frame()
	assert(stale.canceled and tm.preview_jobs.is_empty(),"Ownership invalidates queued jobs")
	tm.planning_deadline = 0
	assert(tm.request_planning(0),"Unrelated movement time cannot starve the planning queue")
	tm.regions = [owned]
	var reset_job := tm.start_preview(0,path)
	tm.initial = [owned]
	tm.fractions = [0.0]
	tm.island_area = 90000
	tm.reset_all()
	assert(reset_job.canceled,"Round reset cancels old jobs")
	tm.free()
	var coast := rect(0,0,300,300)
	for point in [Vector2(10,10),Vector2(128,150),Vector2(299,299),Vector2(-100,200)]:
		assert(ShoreIndex.nearest(coast,point).point.distance_to(point) == IslandGeometry.nearest(coast,point).point.distance_to(point))
	var trail := ConquerTrail.new()
	for i in 1024: trail.append_point(Vector2(i*7,100))
	assert(trail.hits(Vector2(350,0),Vector2(350,200),5))
	assert(not trail.hits(Vector2(350,0),Vector2(350,90),5))
	assert(trail.hits(Vector2(7000,0),Vector2(7000,200),5),"Long swept query reaches the far end of a maximum-length trail")
	trail.clear()
	assert(not trail.hits(Vector2(350,0),Vector2(350,200),5))
	trail.append_point(Vector2(0,0))
	trail.append_point(Vector2(10,10))
	trail._sync_strokes()
	assert(trail.strokes.size() == 4 and not trail.stroke_dirty)
	trail._process(1.0/60)
	assert(not trail.stroke_dirty,"Glow does not rebuild unchanged strokes")
	trail.free()
	print("RESULT resumable topology, shoreline and trail indexes passed")
	quit()
