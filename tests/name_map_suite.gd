extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = "user://profile_test_"+Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(game)
	await process_frame
	var ui: WorldCampaignSelector = game.selector
	assert(ui.editing_name and ui.name_edit.visible)
	ui.name_edit.text = "  Miso  "
	ui.save_name()
	assert(game.campaign.name_saved and game.campaign.player_name == "Miso" and not ui.name_edit.visible and ui.edit_button.visible)
	var restored := CampaignProgress.new()
	restored.path = game.campaign.path
	restored.open(PracticeWallet.new())
	assert(restored.name_saved and restored.player_name == "Miso")
	ui.begin_name_edit()
	ui.name_edit.text = "Changed"
	ui.cancel_name()
	assert(game.campaign.player_name == "Miso" and not ui.editing_name)
	ui.begin_name_edit()
	ui.name_edit.text = "   "
	ui.save_name()
	assert(ui.editing_name and game.campaign.player_name == "Miso")
	game.campaign.path = "user://nonexistent_folder/fail.cfg"
	ui.name_edit.text = "NoSave"
	ui.save_name()
	assert(ui.editing_name and game.campaign.player_name == "Miso")
	for child in ui.get_children(): assert(not child is ItemList and not child is OptionButton)
	var anchor: Vector2 = ui.MAP.get_center()+Vector2(100,50)
	var before: Vector2 = (anchor-ui.MAP.get_center()-ui.pan)/ui.zoom
	ui.zoom_at(2,anchor)
	assert(((anchor-ui.MAP.get_center()-ui.pan)/ui.zoom).is_equal_approx(before))
	assert(not ui.continent_borders.is_empty())
	game.queue_free()
	await process_frame
	print("RESULT 9 name/map checks passed")
	quit()
