// An anime impact frame: for a moment the whole stage is drawn as a stark inverted silhouette, black on a flash of the
// spell's colour, which the eye reads as a blow too strong to see. It lasts two or three frames (BattleStage.impact).
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform vec4 flash : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec3 seen = texture(screen, SCREEN_UV).rgb;
	float light = dot(seen, vec3(0.299, 0.587, 0.114));
	// Bright things (the spell, the rim of a figure) turn black, everything darker takes the flash.
	float ink = smoothstep(0.42, 0.5, light);
	vec3 frame = mix(flash.rgb, vec3(0.02, 0.01, 0.03), ink);
	COLOR = vec4(mix(seen, frame, strength), 1.0);
}
