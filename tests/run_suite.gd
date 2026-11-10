extends SceneTree
var count: int = 0
func verify(value: bool, label: String) -> void:
	assert(value, label)
	count += 1
	print("PASS ", label)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	verify(game.state == game.State.SELECTION, "Selection startup")
	for map in game.catalog.maps:
		verify(map.valid(), map.display_name + " geometry")
	game.start_round()
	var input: MobileInput = game.hud.mobile
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = Vector2(220, 600)
	input._unhandled_input(press)
	verify(input.movement(game.actors[0].position, game.island) == Vector2.ZERO, "Touch starts neutral")
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = press.position + Vector2(64 * root.get_visible_rect().size.x / 720.0, 0)
	input._input(drag)
	verify(input.movement(Vector2.ZERO, game.island).x > 0.99, "Drag steers from touch origin")
	input.release()
	verify(not input.has_target, "Release clears steering")
	game.territory.fractions[0] = 0.999
	game._captured(0, 0.01, Vector2.ZERO)
	verify(game.running, "No early victory at 99.9 percent")
	game.territory.regions[0] = [game.island]
	game.territory.regions[1] = []
	game.territory.regions[2] = []
	game.territory._update_fractions()
	game._captured(0, 0.001, Vector2.ZERO)
	verify(game.state == game.State.ROUND_OVER, "Full ownership wins")
	game.start_round()
	var before: Array[float] = game.territory.fractions.duplicate()
	game._set_state(game.State.DEFEATED)
	game.begin_revive()
	var old: int = game.reward_token
	game.cancel_revive()
	game._reward_completed(old)
	verify(game.state == game.State.DEFEATED, "Canceled reward cannot revive")
	game.begin_revive()
	game.reward.foreground = false
	game.reward._process(1)
	verify(game.reward.remaining == 5, "Background time grants no reward")
	game.reward.foreground = true
	for tick in 51:
		game.reward._process(0.1)
	verify(game.running and game.actors[0].protection == 3, "Completed demo revives with shield")
	verify(game.territory.fractions == before, "Revival preserves territory")
	verify(game.territory.owned(0, game.actors[0].position), "Revival location is owned")
	game._set_state(game.State.DEFEATED)
	game._reward_completed(old)
	verify(game.state == game.State.DEFEATED, "Stale callbacks cannot revive later defeats")
	game.begin_revive()
	game.choose_country()
	game._reward_completed(game.reward.token - 1)
	verify(game.state == game.State.SELECTION, "Home invalidates ad attempts")
	game.start_round()
	game.territory.regions[0] = []
	game._set_state(game.State.DEFEATED)
	game.begin_revive()
	game._reward_completed(game.reward_token)
	verify(game.running and game.territory.owned(0, game.actors[0].position), "No-land revival restores safe patch")
	game.queue_free()
	await process_frame
	print("RESULT ", count, " checks passed")
	quit()

