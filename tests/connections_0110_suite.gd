extends SceneTree
func rect(x: float,y: float,w: float,h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x,y),Vector2(x+w,y),Vector2(x+w,y+h),Vector2(x,y+h)])
func fixture() -> TerritoryManager:
	var tm := TerritoryManager.new()
	tm.config = GameConfig.new()
	tm.island = rect(0,0,300,300)
	tm.island_area = 90000
	tm.regions = [[rect(20,20,20,20),rect(100,20,20,20)],[rect(60,20,10,20)]]
	tm.fractions = [800.0/90000,200.0/90000]
	return tm
func _initialize() -> void:
	for reverse in [false,true]:
		var tm := fixture()
		var path := PackedVector2Array([Vector2(30,30),Vector2(110,30)])
		if reverse: path.reverse()
		var before := tm.regions.duplicate(true)
		assert(tm.preview_capture(0,path).ok and tm.regions == before)
		assert(tm.capture(0,path,PackedVector2Array()))
		assert(tm.owned(0,Vector2(65,30)) and not tm.owned(1,Vector2(65,30)))
		assert(not tm.owned(0,Vector2(65,40)),"No unrelated fill")
		assert(absf(tm.fractions[0]*90000-1250)<1)
		assert(not tm._different_components(0,Vector2(30,30),Vector2(110,30)),"Completed bridge physically joins ownership")
		assert(tm.preview_capture(0,path).area < 0.1,"Duplicate completion grants nothing")
		var snapshot := tm.mesh_snapshot()
		var unchanged = snapshot[0]
		tm.regions[1] = []
		tm._update_fractions()
		assert(tm.mesh_snapshot()[0] == unchanged,"Unchanged team mesh retained")
		tm.free()
	var tm := fixture()
	var interrupted := PackedVector2Array([Vector2(30,30),Vector2(75,30)])
	assert(tm.preview_capture(0,interrupted).area == 0,"Incomplete bridge has no ribbon")
	var bent := PackedVector2Array([Vector2(30,30),Vector2(50,90),Vector2(90,90),Vector2(110,30)])
	assert(tm.capture(0,bent,PackedVector2Array()))
	assert(tm.owned(0,Vector2(70,90)) and not tm.owned(0,Vector2(70,60)))
	tm.begin_planning_frame()
	assert(tm.request_planning(1))
	assert(not tm.request_planning(2))
	tm.begin_planning_frame()
	assert(not tm.request_planning(1))
	assert(tm.request_planning(2))
	tm.begin_planning_frame()
	assert(tm.request_planning(1))
	assert(not tm.request_planning(2))
	var excursion := tm.closed_excursion(0,PackedVector2Array([Vector2(30,30),Vector2(110,30),Vector2(200,100),Vector2(30,30)]))
	assert(excursion.size() >= 3 and excursion[-1].is_equal_approx(Vector2(110,30)),"Preview stops on first actual home entry")
	var errors_before := IslandGeometry.subtraction_errors
	var difference := IslandGeometry.subtract(rect(0,0,100,100),rect(40,40,20,20))
	var area: float = 0
	for piece in difference: area += IslandGeometry.area(piece)
	assert(absf(area-9600)<0.1 and IslandGeometry.subtraction_errors == errors_before)
	var fallback := IslandGeometry.subtract(rect(0,0,100,100),rect(40,40,20,20),12)
	assert(fallback == [rect(0,0,100,100)] and IslandGeometry.subtraction_errors == errors_before+1,"Unresolved boolean retains input for transaction rollback")
	tm.free()
	print("RESULT 28 connection/cache/planning/precision assertions passed")
	quit()
