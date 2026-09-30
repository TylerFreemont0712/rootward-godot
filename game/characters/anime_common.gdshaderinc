// Shared by the anime shaders (ADR-0029): colour grading through a 32^3 LUT strip (1024x32: 32 tiles of 32x32, the
// tile by blue, x by red, y by green), read through the LogC curve Unity's post-processing uses (the curve the LUT
// was authored for). `amount` 0 leaves the colour alone.

vec3 logc(vec3 linear) {
	return clamp(log2(linear * 5.555556 + 0.047996) * 0.07408683 + 0.386036, 0.0, 1.0);
}

vec3 grade(vec3 linear, sampler2D strip, float amount) {
	if (amount <= 0.0) {
		return linear;
	}
	vec3 c = logc(linear) * 31.0;
	float slice = floor(c.b);
	float blend = c.b - slice;
	vec2 texel = vec2(1.0 / 1024.0, 1.0 / 32.0);
	vec2 uv = vec2((c.r + 0.5) * texel.x + slice / 32.0, (c.g + 0.5) * texel.y);
	vec3 a = texture(strip, uv).rgb;
	vec3 b = texture(strip, uv + vec2(1.0 / 32.0, 0.0)).rgb;
	return mix(linear, mix(a, b, blend), amount);
}
