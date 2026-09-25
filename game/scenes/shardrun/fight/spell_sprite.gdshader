// A spell sprite as light (ADR-0008): added onto the stage, never painted over it. One shader, a few dials, so every
// effect is the same drawing moved differently:
//   dissolve  0 whole .. 1 gone: the sprite breaks up along a noise field, a hot edge in `edge_colour` leading;
//   reveal    0 .. 1: an angular wipe clockwise from the top, a bright pen tip at its front (a seal being drawn);
//   distort   a wobble of the picture along scrolling noise (flame, wind, a living bolt);
//   shimmer   a slow ripple of brightness across it (a ward holding);
//   wipe      0 .. 1: revealed from the top down (wipe_dir 1, a beam falling) or the bottom up (-1, a pillar rising),
//             its front lit.
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
uniform float wipe : hint_range(0.0, 1.0) = 1.0;
uniform float wipe_dir = 1.0;
// An animated effect is a sheet of frames: the quad is drawn over `frame_rect` (the first frame's place in the sheet,
// in UV units) and shows `current_rect`. A single picture leaves both at the whole texture.
uniform vec4 frame_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 current_rect = vec4(0.0, 0.0, 1.0, 1.0);

void fragment() {
	// Where in the effect this pixel is (0..1 across it), whatever frame of a sheet is showing.
	vec2 local = (UV - frame_rect.xy) / frame_rect.zw;
	vec2 wobble = (texture(noise, local * 1.6 + TIME * flow).rg - 0.5) * distort * 0.08;
	vec4 drawn = texture(TEXTURE, current_rect.xy + clamp(local + wobble, 0.0, 1.0) * current_rect.zw);
	float grain = texture(noise, local * grain_scale + vec2(0.37, 0.11)).r;
	grain = mix(grain, clamp(length(local - 0.5) * 1.6, 0.0, 1.0) * 0.75 + grain * 0.25, radial);

	// LEARN: a dissolve keeps a pixel while its noise is above the threshold; the pixels just above it, the ones about
	// to go, are the edge, and lighting them makes the break-up read as burning away rather than fading.
	float keep = smoothstep(dissolve - 0.015, dissolve + 0.015, grain);
	float edge = (1.0 - smoothstep(0.0, edge_width, grain - dissolve)) * step(0.001, dissolve) * keep;

	vec2 from_centre = local - 0.5;
	float angle = fract(atan(from_centre.x, -from_centre.y) / 6.2831853);
	float drawn_so_far = 1.0 - smoothstep(reveal - 0.015, reveal + 0.015, angle);
	float pen = (1.0 - smoothstep(0.0, 0.05, abs(angle - reveal))) * step(0.001, reveal) * (1.0 - step(0.999, reveal));

	float along = wipe_dir > 0.0 ? local.y : 1.0 - local.y;
	float wiped = 1.0 - smoothstep(wipe - 0.03, wipe + 0.03, along);
	float front = (1.0 - smoothstep(0.0, 0.05, abs(along - wipe))) * (1.0 - step(0.999, wipe));

	float ripple = 1.0 + shimmer * (texture(noise, local * 2.2 + vec2(0.0, TIME * 0.45)).r - 0.5) * 2.0;
	vec3 light = drawn.rgb * tint.rgb * glow * ripple + edge_colour.rgb * (edge * 0.9 + pen * 1.2 + front * 1.4);
	float alpha = drawn.a * keep * drawn_so_far * wiped * tint.a;
	COLOR = vec4(light, clamp(alpha + (edge * 0.45 + pen * 0.6 + front * 0.5) * drawn.a * tint.a, 0.0, 1.0));
}
