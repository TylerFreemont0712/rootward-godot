// A spell sprite as light (ADR-0008): added onto the stage, never painted over it. One shader, a few dials, so every
// effect is the same drawing moved differently:
//   dissolve  0 whole .. 1 gone: the sprite breaks up along a noise field, a hot edge in `edge_colour` leading;
//   reveal    0 .. 1: an angular wipe clockwise from the top, a bright pen tip at its front (a seal being drawn);
//   distort   a wobble of the picture along scrolling noise (flame, wind, a living bolt);
//   shimmer   a slow ripple of brightness across it (a ward holding).
shader_type canvas_item;
render_mode blend_add;

uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 edge_colour : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float glow = 1.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width = 0.09;
uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform float distort = 0.0;
uniform float shimmer = 0.0;
// How much the break-up follows the distance from the centre instead of the noise alone: 0 anywhere, 1 from the core
// out (a burst burns out from its heart into wisps).
uniform float radial = 0.0;
uniform float grain_scale = 1.25;
uniform vec2 flow = vec2(-0.7, 0.0);

void fragment() {
	vec2 wobble = (texture(noise, UV * 1.6 + TIME * flow).rg - 0.5) * distort * 0.08;
	vec4 drawn = texture(TEXTURE, UV + wobble);
	float grain = texture(noise, UV * grain_scale + vec2(0.37, 0.11)).r;
	grain = mix(grain, clamp(length(UV - 0.5) * 1.6, 0.0, 1.0) * 0.75 + grain * 0.25, radial);

	// LEARN: a dissolve keeps a pixel while its noise is above the threshold; the pixels just above it, the ones about
	// to go, are the edge, and lighting them makes the break-up read as burning away rather than fading.
	float keep = smoothstep(dissolve - 0.015, dissolve + 0.015, grain);
	float edge = (1.0 - smoothstep(0.0, edge_width, grain - dissolve)) * step(0.001, dissolve) * keep;

	vec2 from_centre = UV - 0.5;
	float angle = fract(atan(from_centre.x, -from_centre.y) / 6.2831853);
	float drawn_so_far = 1.0 - smoothstep(reveal - 0.015, reveal + 0.015, angle);
	float pen = (1.0 - smoothstep(0.0, 0.05, abs(angle - reveal))) * step(0.001, reveal) * (1.0 - step(0.999, reveal));

	float ripple = 1.0 + shimmer * (texture(noise, UV * 2.2 + vec2(0.0, TIME * 0.45)).r - 0.5) * 2.0;
	vec3 light = drawn.rgb * tint.rgb * glow * ripple + edge_colour.rgb * (edge * 0.9 + pen * 1.2);
	float alpha = drawn.a * keep * drawn_so_far * tint.a;
	COLOR = vec4(light, clamp(alpha + (edge * 0.45 + pen * 0.6) * drawn.a * tint.a, 0.0, 1.0));
}
