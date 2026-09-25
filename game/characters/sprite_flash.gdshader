// A sprite character's hit or cast flash: the drawing mixed toward one colour by the flash's alpha, its own alpha kept.
shader_type canvas_item;

uniform vec4 flash : source_color = vec4(1.0, 1.0, 1.0, 0.0);

void fragment() {
	vec4 drawn = texture(TEXTURE, UV);
	COLOR = vec4(mix(drawn.rgb, flash.rgb, flash.a), drawn.a);
}
