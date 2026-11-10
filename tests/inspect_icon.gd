extends SceneTree
func _initialize() -> void:
	var image: Image = load("res://assets/icons/foreground.png").get_image()
	print("ALL_ALPHA_RECT ", image.get_used_rect())
	for threshold in [0.01, 0.1, 0.2, 0.5, 0.9]:
		var rect := Rect2i(1024, 1024, 0, 0)
		var first: bool = true
		var count: int = 0
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).a >= threshold:
					count += 1
					if first:
						rect = Rect2i(x, y, 1, 1)
						first = false
					else:
						rect = rect.expand(Vector2i(x, y))
		print("ALPHA ", threshold, " RECT ", rect, " PIXELS ", count)
	quit()
