shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.77778, 1.0);
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float bloom = sin(progress * 3.14159265);
	float coverage = progress < 0.5 ? progress * 2.0 : (1.0 - progress) * 2.0;
	float front = mix(-0.22, 1.42, coverage);
	float mist = noise(p * 5.0 + vec2(progress * 0.6, -progress * 0.4));
	mist += noise(p * 12.0 - vec2(progress, progress * 0.3)) * 0.35;
	float warp = (mist - 0.65) * 0.13;
	float alpha = smoothstep(radius + warp - 0.16, radius + warp + 0.16, front);
	alpha *= smoothstep(0.0, 0.04, progress) * (1.0 - smoothstep(0.96, 1.0, progress));
	float rim = exp(-pow((radius + warp - front) / 0.055, 2.0));
	float outer_ring = exp(-pow((radius - 0.32) / 0.003, 2.0));
	float inner_ring = exp(-pow((radius - 0.29) / 0.002, 2.0));
	float ticks = pow(abs(cos(angle * 16.0 + progress * 0.4)), 28.0);
	float spokes = exp(-pow((radius - 0.305) / 0.018, 2.0)) * ticks;
	float arcs = smoothstep(0.05, 0.4, sin(angle * 3.0 - progress * 1.5));
	float sigil = (outer_ring * arcs + inner_ring * 0.4 + spokes) * pow(bloom, 3.0);
	vec2 star_grid = UV * vec2(95.0, 54.0) + vec2(progress * 1.8, -progress * 4.0);
	float seed = hash(floor(star_grid));
	float spark = exp(-dot(fract(star_grid) - 0.5, fract(star_grid) - 0.5) * 180.0);
	spark *= step(0.985, seed) * bloom * smoothstep(0.1, 0.8, mist);
	vec3 fog = mix(vec3(0.018, 0.038, 0.043), vec3(0.045, 0.13, 0.145), mist * 0.65);
	fog += vec3(0.10, 0.40, 0.39) * rim * 0.38;
	fog += vec3(0.68, 0.44, 0.17) * sigil * 0.7;
	fog += vec3(0.65, 0.62, 0.36) * spark * 0.65;
	COLOR = vec4(fog, max(alpha, (sigil + spark) * bloom * 0.5));
}
