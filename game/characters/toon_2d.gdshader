// Preserve a painted front-facing character sheet when its skeleton briefly turns parts away from the camera.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D drawing : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 flash : source_color = vec4(1.0, 1.0, 1.0, 0.0);

void fragment() {
	vec3 artwork = texture(drawing, UV).rgb;
	ALBEDO = mix(artwork, flash.rgb, flash.a);
}
