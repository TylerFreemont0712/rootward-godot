shader_type canvas_item;
uniform float clock = 0.0;

void fragment() {
	vec4 painted = texture(TEXTURE, UV);
	vec2 lamp_offset = (UV - vec2(0.81, 0.50)) / vec2(0.085, 0.14);
	vec2 glow_offset = (UV - vec2(0.105, 0.735)) / vec2(0.05, 0.07);
	float lamp = exp(-dot(lamp_offset, lamp_offset) * 2.0);
	float glow = exp(-dot(glow_offset, glow_offset) * 2.0);
	painted.rgb *= 1.0 + lamp * (sin(clock * 2.1) * 0.012 + sin(clock * 4.3) * 0.006);
	painted.rgb += vec3(0.015, 0.05, 0.045) * glow * (0.5 + sin(clock * 0.65) * 0.15);
	COLOR = painted;
}
