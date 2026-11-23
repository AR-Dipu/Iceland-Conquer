extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var catalog := CountryCatalog.new()
	for id in ["bgd","ind","isl","jpn","lka","fji"]:
		var country := catalog.find(id)
		assert(country.valid())
		var before := country.outline.duplicate()
		var context := CountryPresentation.for_country(country)
		assert(context.coasts.size() > 0)
		if id in ["bgd","ind"]: assert(context.borders.size() > 0 and context.lands.size() > 0)
		if id in ["isl","jpn","lka"]: assert(context.borders.is_empty())
		assert(country.outline == before,"Presentation changes no playable geometry")
		for coast in context.coasts:
			for point in coast: assert(point.is_finite())
	var game = load("res://scenes/main.tscn").instantiate()
	game.profile_path = "user://premium_"+Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(game)
	await process_frame
	game.campaign.starting = "isl"
	game.selected_country = "isl"
	game.start_round()
	game.set_physics_process(false)
	assert(game.hud.country_banner.title.text == "ICELAND")
	for width in [528,540,664]:
		var title: Label = game.hud.country_banner.title
		game.hud.country_banner.size = Vector2(width,112)
		for item in catalog.maps:
			var mock := CountryMap.new()
			mock.display_name = item.display_name
			mock.outline = PackedVector2Array([Vector2(0,0),Vector2(10,0),Vector2(0,10)])
			game.hud.country_banner.set_country(mock)
			var measured := ConquestTheme.get_font().get_multiline_string_size(title.text,HORIZONTAL_ALIGNMENT_LEFT,title.size.x,title.get_theme_font_size("font_size"))
			assert(measured.y <= 72,"Country title must fit two lines: "+title.text)
	for mode in ["paused","defeated","round_over","demo_ad"]:
		game.hud.set_mode(mode,0)
		for button in [game.hud.coin_button,game.hud.revive_button,game.hud.replay_button,game.hud.country_button,game.hud.resume_button,game.hud.cancel_button]:
			if button.visible: assert(button.size.y >= 136 and button.position.y+button.size.y <= 1200)
	game.hud.set_mode("defeated")
	assert(game.hud.coin_button.text == "REVIVE — 100 COINS")
	assert(game.hud.replay_button.text == "RESTART — FREE")
	var tm: TerritoryManager = game.territory
	var snapshot := tm.mesh_snapshot()
	var old_revision := tm.mesh_revision
	tm.regions[1] = []
	tm._update_fractions()
	assert(tm.render_snapshot() == snapshot and tm.mesh_revision == old_revision)
	tm._pump_meshes()
	tm._pump_meshes()
	assert(tm.mesh_revision == tm.revision and tm.render_snapshot()[1].pieces.is_empty())
	game.queue_free()
	await process_frame
	print("RESULT country geography, premium controls and atomic render snapshots passed")
	quit()
