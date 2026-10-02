shader_type canvas_item;
uniform float feather = 0.08;
uniform float opacity = 0.78;

void fragment() {
	float across = smoothstep(0.0, feather, UV.x) * (1.0 - smoothstep(1.0 - feather, 1.0, UV.x));
	float down = smoothstep(0.0, 0.04, UV.y) * (1.0 - smoothstep(0.95, 1.0, UV.y));
	COLOR = vec4(0.022, 0.038, 0.042, across * down * opacity);
}
