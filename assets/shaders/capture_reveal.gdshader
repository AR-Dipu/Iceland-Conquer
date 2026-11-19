shader_type canvas_item;
uniform vec4 tint : source_color;
uniform vec2 origin;
uniform float radius = 1.0;
uniform float progress = 0.0;
varying vec2 local_point;
void vertex() { local_point = VERTEX; }
void fragment() {
	float reveal = smoothstep(0.0, 0.15, progress * 1.8 - distance(local_point, origin) / radius);
	COLOR = vec4(tint.rgb, reveal * (1.0 - progress) * 0.3);
}
