class_name TropicalOcean
extends ColorRect

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
	void fragment() {
		vec2 p = FRAGCOORD.xy / 160.0;
		float w = sin(p.x * 2.2 + sin(p.y * 2.9 + TIME * 0.22)) * sin(p.y * 3.1 - TIME * 0.3 + cos(p.x * 2.0));
		float foam = smoothstep(0.8, 1.0, w) * 0.10;
		vec3 water = mix(vec3(0.015,0.40,0.64),vec3(0.02,0.72,0.78),0.5+sin(p.x*0.4+p.y*0.3)*0.12);
		COLOR = vec4(water + vec3(foam*0.5,foam,foam),1.0);
	}"""
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	material = shader_material
