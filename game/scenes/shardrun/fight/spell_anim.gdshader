// LEARN: premultiplied alpha adds light and darkens behind in one pass (docs/LEARNING_LOG.md).
// A spell animation from the pipeline (ADR-0014): the sheet's red channel is light, its green channel shade. Light is
// coloured through the element's ramp (dark, mid, hot; the hot end a pale tint, never white) and added; shade darkens
// what lies behind. Premultiplied alpha does both in one pass: out = emitted + behind * (1 - shade).
shader_type canvas_item;
render_mode blend_premul_alpha;

uniform vec4 dark : source_color = vec4(0.11, 0.04, 0.23, 1.0);
uniform vec4 mid : source_color = vec4(0.61, 0.42, 1.0, 1.0);
uniform vec4 hot : source_color = vec4(0.92, 0.86, 1.0, 1.0);
uniform float intensity = 1.0;
uniform float shade_strength = 0.6;

void fragment() {
	vec4 painted = texture(TEXTURE, UV);
	float light = clamp(painted.r * intensity, 0.0, 1.0);
	float shade = clamp(painted.g * shade_strength, 0.0, 1.0);
	vec3 colour = light < 0.5 ? mix(dark.rgb, mid.rgb, light * 2.0) : mix(mid.rgb, hot.rgb, (light - 0.5) * 2.0);
	float fade = COLOR.a;
	COLOR = vec4(colour * light * fade, shade * fade);
}
