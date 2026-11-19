shader_type canvas_item;
void fragment() {
	COLOR.a *= 0.85 + 0.15 * sin(TIME * 3.0);
}
