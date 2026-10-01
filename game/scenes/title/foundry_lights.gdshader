shader_type canvas_item;

uniform float clock = 0.0;
uniform float movement = 1.0;

float pool(vec2 uv, vec2 center, vec2 radius) {
	vec2 offset = (uv - center) / radius;
	return exp(-dot(offset, offset) * 2.0);
}

void fragment() {
	vec4 painted = texture(TEXTURE, UV);
	float lanterns = pool(UV, vec2(0.616, 0.24), vec2(0.04, 0.075));
	lanterns += pool(UV, vec2(0.712, 0.252), vec2(0.045, 0.075));
	lanterns += pool(UV, vec2(0.667, 0.775), vec2(0.05, 0.085));
	lanterns += pool(UV, vec2(0.92, 0.357), vec2(0.04, 0.07));
	float core = pool(UV, vec2(0.56, 0.98), vec2(0.12, 0.24));
	float flicker = sin(clock * 2.3) * 0.017 + sin(clock * 4.7 + UV.y * 7.0) * 0.008;
	float breathing = sin(clock * 0.43) * 0.012;
	painted.rgb *= 1.0 + movement * (min(lanterns, 1.0) * flicker + core * breathing);
	COLOR = painted;
}
