extends SceneTree
const Collection = preload("res://scripts/character_collection.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	seed(115)
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = "user://arcade_" + Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(game)
	game.set_physics_process(false)
	assert(Collection.CATALOG.size() == 12)
	assert(game.collection.owns("frog") and game.collection.owns("fox"))
	assert(game.wallet.balance == 100 and game.collection.buy("gecko"))
	assert(game.wallet.balance == 0 and game.collection.buy("gecko") and game.wallet.balance == 0)
	assert(game.collection.equip("gecko"))
	game.difficulty = 2
	game.start_round()
	var appearances: Dictionary = {}
	for actor in game.actors:
		assert(not appearances.has(actor.appearance_id))
		appearances[actor.appearance_id] = true
		if actor.team > 0: assert(actor.movement_speed() == 210.0 and actor.movement_acceleration() == 1600.0)
	assert(game.actors[0].appearance_id == "gecko")
	game.actors[1].trail.points = PackedVector2Array([Vector2(10,10),Vector2(70,40)])
	game.actors[2].trail.points = PackedVector2Array([Vector2(10,70),Vector2(70,70)])
	for team in [1,2,3]: game.eliminate_bot(team)
	assert(game.trail_echoes.size() == 2 and game.actors[1].trail.points.is_empty())
	assert(game.try_newcomer())
	appearances.clear()
	for actor in game.actors:
		if not actor.active: continue
		assert(not appearances.has(actor.appearance_id))
		appearances[actor.appearance_id] = true
	for actor in game.actors.slice(1): actor.active = false
	game.territory.fractions[0] = 0.99
	game._check_victory(0)
	assert(game.hud.earned_coins == {"First conquest":25})
	assert(game.wallet.balance == 25 and game.campaign.conquered.has("bgd"))
	game.choose_country()
	game.selector.select("bgd")
	assert(game.selector.can_play() and game.selector.play_button.text == "REPLAY CONQUEST")
	game.start_round()
	assert(game.running and game.hud.earned_coins.is_empty())
	for actor in game.actors.slice(1): actor.active = false
	game.territory.fractions[0] = 0.99
	game.active_seconds = 120
	game._check_victory(0)
	assert(game.hud.earned_coins == {"Match objective":25} and game.wallet.balance == 50)
	game.begin_bonus()
	var token: int = game.reward_token
	game.cancel_revive()
	assert(game.hud.earned_coins == {"Match objective":25} and game.wallet.balance == 50)
	game.begin_bonus()
	token = game.reward_token
	game._reward_completed(token)
	assert(game.hud.earned_coins == {"Match objective":25,"Demo bonus":225})
	assert(game.wallet.balance == 275)
	game._reward_completed(token)
	assert(game.wallet.balance == 275)
	game.queue_free()
	await process_frame
	print("RESULT 12-character roster, premium purchase, reinforcements, country replay and credited rewards passed")
	quit()
