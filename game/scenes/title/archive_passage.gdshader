shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
// Width over height of what the veil covers, so the sigil stays round in any window.
uniform float aspect = 1.77778;

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

float ring(float radius, float target, float width) {
	return exp(-pow((radius - target) / width, 2.0));
}

float stroke(vec2 p, vec2 a, vec2 b, float width) {
	vec2 edge = b - a;
	float along = clamp(dot(p - a, edge) / dot(edge, edge), 0.0, 1.0);
	return exp(-pow(length(p - a - edge * along) / width, 2.0));
}

float circle_sigil(vec2 p, float radius, float angle) {
	float turn = progress * 0.22;
	float fine = 0.0012;
	float ink = ring(radius, 0.32, 0.002) + ring(radius, 0.312, fine);
	ink += ring(radius, 0.272, fine) + ring(radius, 0.264, 0.002);
	ink += ring(radius, 0.205, fine) * 0.7;
	// A slow counter-rotating alphabet: stems, branches and diamond marks in 32 cells.
	float cell_angle = mod(angle - turn + 3.14159265, 6.2831853 / 32.0) - 3.14159265 / 32.0;
	float cell = floor((angle - turn + 3.14159265) / (6.2831853 / 32.0));
	vec2 rune = vec2(cell_angle * 0.292, radius - 0.292);
	float variant = mod(cell, 4.0);
	float glyph = stroke(rune, vec2(0.0, -0.012), vec2(0.0, 0.012), fine);
	glyph += stroke(rune, vec2(-0.008, -0.004), vec2(0.0, 0.006), fine);
	glyph += stroke(rune, vec2(0.0, 0.006), vec2(0.008, -0.004), fine);
	if (variant > 0.5) {
		glyph += stroke(rune, vec2(-0.008, 0.008), vec2(0.008, 0.008), fine);
	}
	if (variant > 1.5) {
		glyph += stroke(rune, vec2(-0.008, -0.004), vec2(0.0, -0.012), fine);
		glyph += stroke(rune, vec2(0.0, -0.012), vec2(0.008, -0.004), fine);
	}
	ink += glyph * 0.8;
	// Two interlocking triangles with six small seals on their vertices.
	for (int i = 0; i < 6; i++) {
		float theta = float(i) * 1.04719755 - turn - 1.5707963;
		vec2 a = vec2(cos(theta), sin(theta)) * 0.246;
		vec2 b = vec2(cos(theta + 2.0943951), sin(theta + 2.0943951)) * 0.246;
		ink += stroke(p, a, b, fine) * 0.65;
		float seal = length(p - a);
		ink += ring(seal, 0.012, fine) + ring(seal, 0.006, fine) * 0.6;
	}
	ink += ring(radius, 0.09, fine) + ring(radius, 0.082, fine) * 0.7;
	float inner_turn = angle + turn;
	vec2 center = vec2(cos(inner_turn), sin(inner_turn)) * radius;
	ink += stroke(center, vec2(0.0, -0.062), vec2(0.035, 0.0), fine);
	ink += stroke(center, vec2(0.035, 0.0), vec2(0.0, 0.062), fine);
	ink += stroke(center, vec2(0.0, 0.062), vec2(-0.035, 0.0), fine);
	ink += stroke(center, vec2(-0.035, 0.0), vec2(0.0, -0.062), fine);
	ink += stroke(center, vec2(-0.052, 0.0), vec2(0.052, 0.0), fine);
	ink += ring(radius, 0.34, fine) * pow(abs(cos(angle * 48.0 - turn)), 28.0) * 0.6;
	return ink * pow(sin(progress * 3.14159265), 1.5);
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(aspect, 1.0);
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
	float sigil = circle_sigil(p, radius, angle);
	float breath = sin(progress * 3.14159265);
	// A faint whole-screen mist precedes the advancing edge, easing into the circle.
	alpha = max(alpha, breath * 0.12);
	vec2 star_grid = UV * vec2(95.0, 54.0) + vec2(progress * 1.8, -progress * 4.0);
	float seed = hash(floor(star_grid));
	float spark = exp(-dot(fract(star_grid) - 0.5, fract(star_grid) - 0.5) * 180.0);
	spark *= step(0.985, seed) * bloom * smoothstep(0.1, 0.8, mist);
	vec3 fog = mix(vec3(0.018, 0.038, 0.043), vec3(0.045, 0.13, 0.145), mist * 0.65);
	fog += vec3(0.10, 0.40, 0.39) * rim * 0.38;
	fog += vec3(0.68, 0.44, 0.17) * sigil * 1.05;
	fog += vec3(0.65, 0.62, 0.36) * spark * 0.65;
	float opening = smoothstep(0.0, 0.085, progress) * (1.0 - smoothstep(0.915, 1.0, progress));
	COLOR = vec4(fog, max(alpha, (sigil + spark) * bloom * 0.5) * opening);
}
