extends SceneTree
func _initialize() -> void:
	for filename in ["launcher.png", "foreground.png"]:
		var path: String = "res://assets/icons/" + filename
		var image: Image = Image.load_from_file(path)
		if image.get_width() != 1024 or image.get_height() != 1024:
			image.resize(1024, 1024, Image.INTERPOLATE_LANCZOS)
			image.save_png(path)
		print(filename, " ", image.get_size())
	quit()
