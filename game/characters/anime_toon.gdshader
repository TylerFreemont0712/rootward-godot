// The anime look (ADR-0029) for bodies, hair and clothes: a hard light/shade split whose shade is a colour of its own
// per material slot (warm on skin, cool on cloth), a sharp specular band where a mask allows it, and an optional
// colour-grading LUT over it all. Unshaded: the light is a direction the stage hands in (`light_dir`), so every skin
// is lit the same way whatever lights the scene has.
//
// `mask` (optional) picks the slot per pixel from its red channel (five bands: >=0.8 slot 1 ... <0.2 slot 5) and the
// specular strength from its blue. With no mask every pixel is slot 1 with no specular.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D diffuse : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mask : filter_linear_mipmap, repeat_enable;
uniform bool use_mask = false;
// A mask saved as colour (sRGB) is decoded before its bands are read; one saved as data is read as it is.
uniform bool mask_srgb = true;
// A painted shade (VRoid's shade texture times its shade colour) instead of a slot colour: the artist's own shadows.
uniform sampler2D shade_map : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform bool use_shade_map = false;
uniform vec4 shade_tint : source_color = vec4(1.0);
uniform vec4 lit_tint : source_color = vec4(1.0);
uniform vec4 shadow_1 : source_color = vec4(0.85, 0.75, 0.71, 1.0);
uniform vec4 shadow_2 : source_color = vec4(0.49, 0.51, 0.58, 1.0);
uniform vec4 shadow_3 : source_color = vec4(0.57, 0.58, 0.65, 1.0);
uniform vec4 shadow_4 : source_color = vec4(1.0, 0.8, 0.74, 1.0);
uniform vec4 shadow_5 : source_color = vec4(0.57, 0.58, 0.65, 1.0);
uniform vec4 specular_1 : source_color = vec4(1.0);
uniform vec4 specular_2 : source_color = vec4(1.0);
uniform vec4 specular_3 : source_color = vec4(0.91, 0.96, 1.0, 1.0);
uniform vec4 specular_4 : source_color = vec4(1.0);
uniform vec4 specular_5 : source_color = vec4(1.0);
// How much of N.L the light/shade edge takes to cross (0 is a knife edge).
uniform float edge = 0.25;
uniform float specular_from = 0.75;
uniform vec3 light_dir = vec3(0.4, 0.6, 0.7);
uniform float alpha_cut = 0.5;
// Painted game textures carry their own soft lighting; cel art wants flat colour. `flatten` divides out the texture's
// low-frequency brightness (a blurred mip of itself), keeping its colours and fine detail (0 leaves it as painted).
uniform float flatten = 0.0;
uniform float flatten_mip = 4.0;
// A thin light along the silhouette on the lit side (0 is none), as anime games separate a figure from its ground.
uniform float rim = 0.0;
uniform vec4 rim_colour : source_color = vec4(1.0, 0.95, 0.9, 1.0);
// A 32x32x32 colour LUT laid out as a 1024x32 strip, read through a LogC curve (see anime_common.gdshaderinc).
uniform sampler2D lut : filter_linear, repeat_disable;
uniform float lut_amount = 0.0;
// A hit or a cast flashes the whole character (StageCharacter.set_flash); alpha is its strength.
uniform vec4 flash = vec4(0.0);

#include "res://characters/anime_common.gdshaderinc"

varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 by_slot(float id, vec3 a, vec3 b, vec3 c, vec3 d, vec3 e) {
	return id >= 0.8 ? a : id >= 0.6 ? b : id >= 0.4 ? c : id >= 0.2 ? d : e;
}

void fragment() {
	vec4 albedo = texture(diffuse, UV);
	if (albedo.a < alpha_cut) {
		discard;
	}
	if (flatten > 0.0) {
		vec3 broad = textureLod(diffuse, UV, flatten_mip).rgb;
		float broad_luma = max(dot(broad, vec3(0.299, 0.587, 0.114)), 0.02);
		float luma = dot(albedo.rgb, vec3(0.299, 0.587, 0.114));
		vec3 flat_rgb = albedo.rgb * clamp(0.62 / broad_luma, 0.6, 1.8);
		albedo.rgb = mix(albedo.rgb, flat_rgb, flatten * smoothstep(0.02, 0.1, luma));
	}
	vec3 n = normalize(world_normal);
	vec3 l = normalize(light_dir);
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz);
	vec3 h = normalize(l + v);
	vec4 m = use_mask ? texture(mask, UV) : vec4(1.0, 0.0, 0.0, 0.0);
	if (use_mask && mask_srgb) {
		m.rgb = pow(m.rgb, vec3(2.2));
	}
	float lit = clamp(dot(n, l) / max(edge, 0.0001), 0.0, 1.0);
	vec3 shade = by_slot(m.r, shadow_1.rgb, shadow_2.rgb, shadow_3.rgb, shadow_4.rgb, shadow_5.rgb);
	vec3 spec_colour = by_slot(m.r, specular_1.rgb, specular_2.rgb, specular_3.rgb, specular_4.rgb, specular_5.rgb);
	float spec = clamp((dot(n, h) - specular_from) / (1.0 - specular_from), 0.0, 1.0) * m.b * lit;
	vec3 lit_rgb = albedo.rgb * lit_tint.rgb;
	vec3 shade_rgb = use_shade_map ? texture(shade_map, UV).rgb * shade_tint.rgb : lit_rgb * shade;
	vec3 colour = mix(shade_rgb, lit_rgb, lit) + spec_colour * spec;
	float fresnel = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 4.0);
	colour += rim_colour.rgb * rim * smoothstep(0.5, 0.7, fresnel) * clamp(dot(n, l) + 0.3, 0.0, 1.0);
	colour = grade(colour, lut, lut_amount);
	ALBEDO = mix(colour, flash.rgb, flash.a);
}
