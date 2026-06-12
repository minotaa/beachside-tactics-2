shader_type canvas_item;

void fragment() {
	float alpha = texture(TEXTURE, UV).a;
	COLOR = vec4(0.05, 0.05, 0.08, alpha * 0.5);
}