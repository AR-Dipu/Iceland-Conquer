class_name ConquestTheme
extends RefCounted
const INK := Color("252c2b")
const PANEL := Color("353e38")
const PURPLE := Color("5b4269")
const GOLD := Color("dcba79")
const CREAM := Color("fff0cf")
const MUTED := Color("cdc1a8")
static var display_font: Font

static func heading_font() -> Font:
	if display_font == null:
		if OS.get_name() == "Android":
			var android_serif := FontFile.new()
			if android_serif.load_dynamic_font("/system/fonts/NotoSerif-Bold.ttf") == OK:
				display_font = android_serif
		if display_font == null:
			var system_serif := SystemFont.new()
			system_serif.font_names = PackedStringArray(["Noto Serif", "Georgia", "serif"])
			system_serif.font_weight = 700
			display_font = system_serif
	return display_font
static var font: FontVariation
static var shared: Theme
static var panels: Dictionary = {}
static func get_font() -> FontVariation:
	if font == null:
		font = FontVariation.new()
		font.base_font = preload("res://assets/fonts/Fredoka.ttf")
		font.variation_opentype = {"wght":700.0}
		font.variation_embolden = 0.5
	return font
static func panel(color: Color = PANEL, edge: Color = Color("877656"), radius: int = 12) -> StyleBoxFlat:
	var key := str(color)+":"+str(edge)+":"+str(radius)
	if panels.has(key): return panels[key]
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.02,0.04,0.1,0.25)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0,4)
	style.content_margin_left = 18
	style.content_margin_right = 18
	panels[key] = style
	return style
static func get_theme() -> Theme:
	if shared != null: return shared
	shared = Theme.new()
	shared.default_font = get_font()
	shared.default_font_size = 24
	shared.set_color("font_color","Label",CREAM)
	for state in ["normal","hover","pressed","disabled","focus"]:
		var color := PANEL if state == "normal" else PURPLE if state in ["hover","pressed"] else Color.TRANSPARENT if state == "focus" else Color("28354a")
		shared.set_stylebox(state,"Button",panel(color,GOLD if state == "focus" else Color("45617e")))
	shared.set_color("font_color","Button",CREAM)
	shared.set_color("font_hover_color","Button",Color.WHITE)
	shared.set_color("font_pressed_color","Button",GOLD)
	shared.set_color("font_disabled_color","Button",Color("8b99ad"))
	shared.set_stylebox("normal","LineEdit",panel(INK))
	shared.set_stylebox("focus","LineEdit",panel(INK,GOLD))
	shared.set_color("font_color","LineEdit",CREAM)
	shared.set_color("caret_color","LineEdit",GOLD)
	return shared
static func style_button(button: Button, primary: bool = false) -> void:
	button.theme = get_theme()
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size",23)
	if primary:
		button.add_theme_stylebox_override("normal",panel(PURPLE,GOLD))
		button.add_theme_stylebox_override("hover",panel(PURPLE.lightened(0.1),Color("ffe5a1")))
		button.add_theme_stylebox_override("pressed",panel(PURPLE.darkened(0.12),GOLD))
		for state in ["font_color","font_hover_color","font_pressed_color"]: button.add_theme_color_override(state,CREAM)
	button.resized.connect(func() -> void: button.pivot_offset = button.size*0.5)
	button.button_down.connect(func() -> void: _press(button,0.98,0.08))
	button.button_up.connect(func() -> void: _press(button,1.0,0.1))
static func _press(button: Button, scale: float, duration: float) -> void:
	var old: Variant = button.get_meta("press_tween") if button.has_meta("press_tween") else null
	if old != null and old.is_valid(): old.kill()
	var tween := button.create_tween()
	button.set_meta("press_tween",tween)
	tween.tween_property(button,"scale",Vector2.ONE*scale,duration)
