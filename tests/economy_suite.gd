extends SceneTree
var checks: int = 0
func verify(value: bool, label: String) -> void:
	assert(value, label)
	checks += 1
	print("PASS ", label)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var path := "user://test_wallet_" + Crypto.new().generate_random_bytes(8).hex_encode() + ".json"
	var wallet := PracticeWallet.new()
	verify(wallet.open(path) and wallet.balance == 100, "New wallet starts at 100")
	verify(wallet.transact("country:bgd", 25) and wallet.balance == 125, "Completion grants 25")
	verify(wallet.transact("country:bgd", 25) and wallet.balance == 125, "Completion is idempotent")
	verify(wallet.transact("bonus:bgd", 225) and wallet.balance == 350, "Bonus gives 250 total completion payout")
	verify(wallet.transact("bonus:bgd", 225) and wallet.balance == 350, "Bonus cannot repeat")
	verify(wallet.transact("payment:1", -100) and wallet.balance == 250, "First revival deducts 100")
	verify(wallet.transact("payment:1", -100) and wallet.balance == 250, "Duplicate deduction ignored")
	verify(wallet.transact("payment:2", -150) and wallet.balance == 100, "Second revival deducts 150")
	verify(not wallet.transact("payment:3", -200) and wallet.balance == 100, "Insufficient balance unchanged")
	var reopened := PracticeWallet.new()
	verify(reopened.open(path) and reopened.balance == 100, "Wallet persists after reopen")
	verify(reopened.daily_login() and reopened.balance == 100, "First login retains starting 100")
	verify(not reopened.daily_login(), "Daily cannot repeat")
	var damaged := FileAccess.open(path,FileAccess.WRITE)
	damaged.store_string("broken save")
	damaged.close()
	var recovered := PracticeWallet.new()
	verify(recovered.open(path),"Healthy backup recovers damaged primary")
	verify(recovered.transact("recovered",1),"Recovered wallet can save safely")
	var checked := PracticeWallet.new()
	verify(checked.open(path) and checked.claimed("recovered"),"Recovery persists repaired primary")
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = "user://test_" + Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.wallet = reopened
	game.start_round()
	game._set_state(game.State.DEFEATED)
	game.coin_revive()
	verify(game.running and reopened.balance == 0 and game.coin_revives == 1, "Coin revival resumes and charges once")
	game.coin_revive()
	verify(reopened.balance == 0, "Repeated tap cannot charge")
	game._set_state(game.State.DEFEATED)
	game.coin_revive()
	verify(game.state == game.State.DEFEATED, "Insufficient funds cannot revive")
	game.begin_revive()
	var token: int = game.reward_token
	game.cancel_revive()
	game._reward_completed(token)
	verify(game.state == game.State.DEFEATED and reopened.balance == 0, "Canceled demo grants nothing")
	game.begin_revive()
	game._reward_completed(game.reward_token)
	verify(game.running and reopened.balance == 0, "Demo revival costs no coins")
	game.start_round()
	verify(game.coin_revives == 0 and reopened.balance == 0, "Free restart resets price and preserves wallet")
	game.selected_country = "ind"
	game.campaign.conquered.clear()
	game.campaign.starting = "ind"
	reopened.transact("country:ind", 25)
	game.winning_team = 0
	game._wallet_ui()
	game._set_state(game.State.ROUND_OVER)
	game.begin_bonus()
	var bonus_token: int = game.reward_token
	game._reward_completed(bonus_token)
	verify(reopened.balance == 250 and game.state == game.State.ROUND_OVER, "Completion demo adds exactly 225")
	game._reward_completed(bonus_token)
	verify(reopened.balance == 250 and not game.hud.bonus_ready, "Duplicate bonus callback ignored")
	game.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("RESULT ", checks, " economy checks passed")
	quit()
