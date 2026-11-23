class_name TropicalOcean
extends TextureRect
## Cached background texture: no full-screen animated trigonometry.
var campaign_mode: bool = true
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	set_campaign_mode(campaign_mode)
func set_campaign_mode(value: bool) -> void:
	campaign_mode = value
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("b3996f"),Color("f5e2bb")]) if value else PackedColorArray([Color("4d7d84"),Color("a8bdb2")])
	var image := GradientTexture2D.new()
	image.width = 256
	image.height = 256
	image.gradient = gradient
	image.fill_from = Vector2.ZERO
	image.fill_to = Vector2.ONE
	texture = image
