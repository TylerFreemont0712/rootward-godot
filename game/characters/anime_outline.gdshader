// The anime ink line (ADR-0029): an inverted hull like outline.gdshader, but coloured from the surface it outlines
// (the texture darkened and tinted), as anime games draw their lines: dark plum around skin, near black around dark
// cloth, never one flat black. The width is in screen pixels, so it holds its weight at any distance.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform sampler2D diffuse : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(0.42, 0.3, 0.36, 1.0);
// Line width in pixels at a 900-pixel-high viewport.
uniform float width = 1.6;
uniform float alpha_cut = 0.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 clip_normal = mat3(PROJECTION_MATRIX) * (MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec2 offset = normalize(clip_normal.xy + vec2(1e-5)) / VIEWPORT_SIZE * width * 2.0 * (VIEWPORT_SIZE.y / 900.0);
	clip.xy += offset * clip.w;
	POSITION = clip;
}

void fragment() {
	vec4 albedo = texture(diffuse, UV);
	if (albedo.a < alpha_cut) {
		discard;
	}
	ALBEDO = albedo.rgb * tint.rgb * 0.55;
}
