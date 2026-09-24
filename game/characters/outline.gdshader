// Ink lines: the mesh drawn again a little larger, inside out, in one dark colour (an "inverted hull"). Only its back
// faces survive, so a line shows wherever the character's silhouette or a fold turns away from the camera.
//
// The width is in screen space, so a line stays the same weight however near the camera is.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 ink : source_color = vec4(0.13, 0.08, 0.14, 1.0);
// Line width in pixels at a 900-pixel-high viewport.
uniform float width = 2.2;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 clip_normal = mat3(PROJECTION_MATRIX) * (MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec2 offset = normalize(clip_normal.xy) / VIEWPORT_SIZE * width * 2.0 * (VIEWPORT_SIZE.y / 900.0);
	clip.xy += offset * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = ink.rgb;
}
