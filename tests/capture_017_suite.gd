extends SceneTree
func rect(x: float,y: float,w: float,h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x,y),Vector2(x+w,y),Vector2(x+w,y+h),Vector2(x,y+h)])
func _initialize() -> void:
	var tm := TerritoryManager.new()
	tm.config = GameConfig.new()
	tm.island = rect(0,0,300,300)
	tm.island_area = 90000
	tm.regions = [[rect(20,20,60,60)],[rect(120,50,40,40)]]
	tm.initial = tm.regions.duplicate(true)
	tm.fractions = [0.04,0.0]
	var trail := PackedVector2Array([Vector2(70,30),Vector2(200,30),Vector2(200,150),Vector2(40,150),Vector2(40,70)])
	var preview := tm.preview_capture(0,trail)
	print("PREVIEW ",preview.area," pieces=",preview.pieces.size())
	assert(preview.ok and absf(preview.area-17200) < 1,"Entire bounded area must be captured")
	assert(tm.capture(0,trail,PackedVector2Array()))
	assert(absf(tm.fractions[0]*90000-20800)<1)
	assert(tm.regions[1].is_empty(),"Rival land inside enclosure transfers once")
	assert(tm.owned(0,Vector2(170,140)))
	assert(not tm.owned(0,Vector2(10,200)))
	var before: Array = tm.regions.duplicate(true)
	assert(tm.preview_capture(0,trail).area < 0.1)
	assert(tm.regions == before,"Preview must not mutate")
	tm.regions = [[rect(20,20,20,20),rect(100,20,20,20)],[]]
	assert(tm.preview_capture(0,PackedVector2Array([Vector2(30,30),Vector2(110,30)])).area < 0.1,"Open bridge must not fill unrelated land")
	var crossed := CaptureTopology.enclosed([],PackedVector2Array([Vector2(10,10),Vector2(50,50),Vector2(10,50),Vector2(50,10),Vector2(10,10)]))
	var crossed_area: float = 0
	for face in crossed.faces: crossed_area += IslandGeometry.area(face)
	assert(crossed.ok and absf(crossed_area-800)<0.1,"Self-crossed bounded faces")
	tm.regions = [[IslandGeometry.blob(Vector2(150,150),Vector2.ONE*100,0,6001)],[]]
	var snapshot: Array = tm.regions.duplicate(true)
	assert(not tm.capture(0,trail,PackedVector2Array()) and tm.regions == snapshot,"Invalid/overbudget topology preserves ownership")
	tm.free()
	print("RESULT 11 exact capture checks passed")
	quit()
