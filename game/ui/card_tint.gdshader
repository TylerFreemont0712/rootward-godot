// A card frame in a paradigm's colour (ADR-0012). The frame is painted in grey steel and gold: the grey takes the
// tint, keeping its light and shade, and the gold and the violet mana crystal, which are saturated, stay as painted.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.71, 0.55, 1.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.8;

void fragment() {
	vec4 painted = texture(TEXTURE, UV);
	float high = max(painted.r, max(painted.g, painted.b));
	float low = min(painted.r, min(painted.g, painted.b));
	float saturation = high > 0.0 ? (high - low) / high : 0.0;
	float luma = dot(painted.rgb, vec3(0.299, 0.587, 0.114));
	float grey = 1.0 - smoothstep(0.14, 0.38, saturation);
	vec3 tinted = min(vec3(1.0), luma * tint.rgb * 1.85);
	COLOR = vec4(mix(painted.rgb, tinted, grey * strength), painted.a) * COLOR;
}
