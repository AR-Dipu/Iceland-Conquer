extends SceneTree
var completions: int = 0
func _initialize() -> void:
	var service := DemoRewardService.new()
	root.add_child(service)
	service.completed.connect(func(_token: int) -> void: completions += 1)
	service.begin()
	service.foreground = false
	service._process(1)
	assert(service.remaining == 3)
	service.foreground = true
	for i in 29: service._process(0.1)
	assert(completions == 0)
	service._process(0.1)
	service._process(0.1)
	assert(completions == 1)
	service._process(1)
	assert(completions == 1)
	service.begin()
	service.cancel()
	service._process(10)
	assert(completions == 1)
	print("RESULT 5 three-second demo checks passed")
	quit()
