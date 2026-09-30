// The anime face (ADR-0029): shaded by a signed-distance lightmap, not by its normals, so the shadow falls across it
// as an illustrator would draw it (a clean edge down the nose, a cheek, never a blotch) and sweeps smoothly as the
// light comes round the head. The lightmap is drawn for a light from the face's left; a light from its right reads it
// mirrored. The stage hands in the head's facing (`head_forward`, `head_up`, world space) every frame.
//
// With no lightmap the face is lit flat (the light side's colour everywhere), which suits a painted VRoid face.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform sampler2D diffuse : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D lightmap : filter_linear_mipmap, repeat_enable;
uniform bool use_lightmap = false;
uniform vec4 shadow : source_color = vec4(1.0, 0.75, 0.66, 1.0);
uniform vec3 light_dir = vec3(0.4, 0.6, 0.7);
uniform vec3 head_forward = vec3(0.0, 0.0, 1.0);
uniform vec3 head_up = vec3(0.0, 1.0, 0.0);
// Half the width of the shadow's soft edge, in lightmap values.
uniform float softness = 0.025;
uniform float alpha_cut = 0.5;
uniform sampler2D lut : filter_linear, repeat_disable;
uniform float lut_amount = 0.0;
uniform vec4 flash = vec4(0.0);

#include "res://characters/anime_common.gdshaderinc"

void fragment() {
	vec4 albedo = texture(diffuse, UV);
	if (albedo.a < alpha_cut) {
		discard;
	}
	float lit = 1.0;
	if (use_lightmap) {
		vec3 up = normalize(head_up);
		vec3 forward = normalize(head_forward - dot(head_forward, up) * up);
		// The light flattened onto the head's horizontal plane, then its angle from the front.
		vec3 l = light_dir - dot(light_dir, up) * up;
		l = length(l) > 0.0001 ? normalize(l) : forward;
		vec3 left = cross(up, forward);
		float front = dot(forward, l);
		float side = dot(left, l);
		vec2 uv = side >= 0.0 ? UV : vec2(1.0 - UV.x, UV.y);
		float sdf = texture(lightmap, uv).r;
		// Light from the front lights all of it (threshold 0); from the side, half; from behind, none.
		float threshold = acos(clamp(front, -1.0, 1.0)) / PI;
		lit = smoothstep(threshold - softness, threshold + softness, sdf);
	}
	vec3 colour = albedo.rgb * mix(shadow.rgb, vec3(1.0), lit);
	colour = grade(colour, lut, lut_amount);
	ALBEDO = mix(colour, flash.rgb, flash.a);
}
