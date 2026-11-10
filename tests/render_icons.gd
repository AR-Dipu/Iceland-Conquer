extends SceneTree
var stage: Node2D
var font: Font = preload("res://assets/fonts/Fredoka.ttf")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	root.content_scale_size = Vector2i(800, 460)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	stage = Node2D.new()
	root.add_child(stage)
	stage.draw.connect(draw_labels)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
	uniform sampler2D background;
	uniform bool adaptive = false;
	uniform bool rounded = false;
	void fragment() {
		vec4 fg = texture(TEXTURE,adaptive ? (UV-vec2(0.5))/1.45+vec2(0.5):UV);
		vec4 bg = texture(background,UV);
		vec4 color = adaptive ? vec4(mix(bg.rgb,fg.rgb,fg.a),1.0) : fg;
		vec2 q = abs(UV-vec2(0.5))-vec2(0.40);
		float distance = rounded ? length(max(q,vec2(0.0)))+min(max(q.x,q.y),0.0)-0.10 : length(UV-vec2(0.5))-0.495;
		COLOR=vec4(color.rgb,color.a*(1.0-smoothstep(-0.002,0.002,distance)));
	}"""
	for i in 4:
		for size_px in [160, 48]:
			var icon := TextureRect.new()
			icon.texture = load("res://assets/icons/foreground.png" if i >= 2 else "res://assets/icons/launcher.png")
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.size = Vector2.ONE * size_px
			icon.position = Vector2(20 + i * 200 + (160 - size_px) / 2.0, 101 if size_px == 160 else 326)
			var material := ShaderMaterial.new()
			material.shader = shader
			material.set_shader_parameter("background", load("res://assets/icons/background.svg"))
			material.set_shader_parameter("adaptive", i >= 2)
			material.set_shader_parameter("rounded", i % 2 == 1)
			icon.material = material
			stage.add_child(icon)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/icon-masks.png"))
	quit()
func draw_labels() -> void:
	stage.draw_rect(Rect2(0, 0, 800, 460), Color("083e58"))
	stage.draw_string(font, Vector2(25, 44), "ISLAND CONQUER / LAUNCHER CHECK", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("ffe3a0"))
	for i in 4:
		var label: String = ["Standard / circle", "Standard / rounded", "Adaptive / circle", "Adaptive / rounded"][i]
		stage.draw_string(font, Vector2(21 + i * 200, 291), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
	stage.draw_string(font, Vector2(25, 421), "160 px and 48 px previews. Adaptive layers shown at launcher scale.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("c3edef"))
