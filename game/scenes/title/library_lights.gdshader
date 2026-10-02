shader_type canvas_item;

uniform float clock = 0.0;

void fragment() {
	vec4 painted = texture(TEXTURE, UV);
	vec2 offset = (UV - vec2(0.925, 0.605)) / vec2(0.075, 0.12);
	float lamp = exp(-dot(offset, offset) * 2.0);
	painted.rgb *= 1.0 + lamp * (sin(clock * 2.1) * 0.012 + sin(clock * 4.3) * 0.006);
	COLOR = painted;
}
