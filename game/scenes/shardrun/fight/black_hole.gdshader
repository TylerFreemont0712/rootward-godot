// LEARN: the black-hole impact (docs/LEGENDARY_LOOKS.md, "The black-hole impact"), drawn by BlackHoleImpact on one quad
// 5.0 disc radii across. Every feature is a formula of `progress`, so a frame is a pure function of the timeline (TIME is
// never read) and the same progress always draws the same frame. Each pixel does a fixed amount of work with no loops,
// and at most one screen read (the lens).
//
// LEARN: the output is premultiplied. The lensed screen is `under`, which the horizon's black covers. `glow` and `flash`
// are added on top with no alpha of their own, so light brightens what is there and the horizon blocks it.
shader_type canvas_item;
render_mode blend_premul_alpha;

// The screen under the quad. The BackBufferCopy that holds this quad copies that screen before the quad draws.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float progress = 0.0;
// The disc's radius as a share of the quad's width: 1 / 5.0.
uniform float radius_uv = 0.2;
uniform int bands = 6;
uniform float spin = 0.6;
uniform float tilt = 0.45;
uniform bool jets = true;
uniform float lens = 0.6;
uniform float hue = 0.0;
uniform int photon_sides = 0;
uniform int arms = 0;
uniform bool scanlines = false;
uniform int digits = 0;
uniform bool split = false;
uniform bool cells = false;
uniform int rings = 1;
uniform bool reduced = false;

const float TAU_F = 6.283185307;
// The event horizon's radius at full size, and the photon ring's centre, in disc radii.
const float HORIZON = 0.42;
const float PHOTON = 0.47;
// The accretion disc's inner and outer radii in its own plane.
const float DISC_IN = 0.5;
const float DISC_OUT = 1.3;
// The quad's edge in disc radii: half its 5.0 width. The light fades out between EDGE_FADE and the edge, so no border
// shows. EDGE_FADE lies beyond the shock ring's full length (2.4).
const float QUAD_EDGE = 2.5;
const float EDGE_FADE = 2.44;
// The shock ring's far end in radii (it starts at 0.45). The jets' length in radii. Both lie inside the quad's edge.
const float SHOCK_REACH = 2.4;
const float JET_REACH = 1.9;
const float SHARD_COUNT = 16.0;

// The palette: a + b cos(2 pi (t + d)) with a = b = 1/2 and d = (0, 1/3, 2/3), so each channel runs 0 to 1. `hue` turns it.
vec3 prism(float t) {
	return vec3(0.5) + 0.5 * cos(TAU_F * (fract(t + hue) + vec3(0.0, 0.333333, 0.666667)));
}

// 1 at x0, falling off as a Gaussian of half-width w.
float band(float x, float x0, float w) {
	float d = (x - x0) / w;
	return exp(-d * d);
}

// A cheap hash of n, in [0, 1). It places the shards and picks the digits.
float hash1(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

// The tilted accretion disc. The plane is squashed by the tilt, its bands spiral (three arms, so the angle wraps with no
// seam), and the hot inner edge is the brightest.
vec3 disc_light(vec2 q, float spin_angle, float gain, float scan) {
	float squash = 1.0 - 0.8 * tilt;
	float rd = length(vec2(q.x, q.y / squash));
	float ad = atan(q.y / squash, q.x) + spin_angle;
	float u = clamp((rd - DISC_IN) / (DISC_OUT - DISC_IN), 0.0, 1.0);
	float edge = (1.0 - smoothstep(DISC_OUT - 0.25, DISC_OUT, rd)) * smoothstep(DISC_IN - 0.05, DISC_IN + 0.03, rd);
	float stripes = 0.55 + 0.45 * cos(TAU_F * float(bands) * u + 3.0 * ad);
	float hot = pow(1.0 - u, 1.4);
	vec3 col = mix(vec3(1.0, 0.82, 0.55), prism(u * 0.5 + ad / TAU_F), 0.45);
	return col * edge * (0.25 + 0.75 * hot) * stripes * scan * gain;
}

// The photon ring: one to three thin rings round the hole. `photon_sides` lobes them, the hottest part of each goes white,
// the colour runs round the angle, and `arc` cuts it (memo-ward's eight arcs).
vec3 photon_light(float r, float ang, float p, float arc) {
	float shown = smoothstep(0.12, 0.25, p) * (1.0 - smoothstep(0.7, 0.95, p));
	float thin = band(r, PHOTON, 0.028)
		+ step(1.5, float(rings)) * 0.5 * band(r, PHOTON + 0.09, 0.02)
		+ step(2.5, float(rings)) * 0.3 * band(r, PHOTON + 0.18, 0.018);
	float lobes = photon_sides > 0 ? pow(0.5 + 0.5 * cos(float(photon_sides) * ang), 2.0) : 1.0;
	float strength = thin * lobes * arc * shown;
	float heat = pow(clamp(strength, 0.0, 1.0), 3.0);
	return mix(prism(ang / TAU_F + 0.5 + p * 0.25), vec3(1.0), heat) * strength * 1.4;
}

// The eight arcs memo-ward's photon ring breaks into. From the impact the ring opens a gap at each of eight cuts.
float ring_arcs(float ta, float p) {
	float f = fract(ta * 8.0);
	float to_cut = min(f, 1.0 - f);
	return mix(1.0, smoothstep(0.12, 0.18, to_cut), smoothstep(0.25, 0.34, p));
}

// The shock ring: from the impact it runs out from 0.45 to 2.4 radii and thins. Nothing cuts it short: the quad's edge
// (2.5) lies beyond its full length.
vec3 shock_light(float r, float ang, float p) {
	float s = clamp((p - 0.25) / 0.6, 0.0, 1.0);
	float at_r = mix(0.45, SHOCK_REACH, 1.0 - (1.0 - s) * (1.0 - s));
	float shown = smoothstep(0.25, 0.27, p) * (1.0 - smoothstep(0.9, 1.0, p));
	vec3 col = mix(prism(ang / TAU_F + p * 0.4), vec3(1.0), 0.5);
	return col * band(r, at_r, 0.03 + 0.05 * s) * shown * (1.0 - 0.5 * s) * 1.1;
}

// The two jets, up and down the hole's axis: prismatic beams from the horizon that widen as they reach out. They run out
// to JET_REACH, inside the quad, and their far end is drawn in full.
vec3 jet_light(vec2 q, float p) {
	float shown = smoothstep(0.25, 0.33, p) * (1.0 - smoothstep(0.5, 0.62, p));
	float reach = JET_REACH * smoothstep(0.25, 0.45, p);
	float along = abs(q.y);
	float front = 1.0 - smoothstep(reach - 0.15, reach, along);
	float core = band(q.x, 0.0, 0.025 + 0.1 * along);
	vec3 col = mix(prism(along * 0.5 - p * 0.6), vec3(1.0), 0.7 * core);
	return col * core * front * smoothstep(0.38, 0.5, along) * shown * 1.2;
}

// Inflow: streaks spiral in along `arms` arms, from the rim towards the hole, and thin out at the impact.
vec3 arm_light(float ta, float r, float p) {
	float shown = smoothstep(0.0, 0.02, p) * (1.0 - smoothstep(0.2, 0.3, p));
	float phase = float(arms) * ta + 7.0 * log(max(r, 0.05)) + p * 6.0;
	float streak = smoothstep(0.9, 1.0, fract(phase));
	float window = (1.0 - smoothstep(1.2, 2.0, r)) * smoothstep(HORIZON, PHOTON, r);
	return prism(ta + p) * streak * window * shown * 1.1;
}

// Digits (radix-sort): a ring of small 3x3 glyphs round the disc. Their dots reshuffle as the collapse runs.
vec3 digit_light(float ta, float r, float p) {
	float depth = (r - 1.04) / 0.18;
	if (depth < 0.0 || depth >= 1.0) {
		return vec3(0.0);
	}
	float shown = smoothstep(0.12, 0.25, p) * (1.0 - smoothstep(0.7, 0.95, p));
	float cell_f = ta * float(digits);
	float cell = floor(cell_f);
	vec2 grid = vec2(fract(cell_f), depth) * 3.0;
	vec2 inner = fract(grid);
	float dot_on = step(0.2, inner.x) * step(inner.x, 0.8) * step(0.2, inner.y) * step(inner.y, 0.8);
	float lit = step(0.5, hash1(cell * 9.0 + floor(grid.x) * 3.0 + floor(grid.y) + floor(p * 10.0) * 0.37));
	return mix(vec3(0.95), prism(ta), 0.5) * dot_on * lit * shown * 0.9;
}

// The split at the impact: a bright beam through the disc along its equator. It narrows and fades within a fifth of the
// timeline.
vec3 split_light(vec2 q, float p) {
	float dt = p - 0.25;
	float age = clamp(dt * 5.0, 0.0, 1.0);
	float life = step(0.0, dt) * exp(-max(dt, 0.0) * 9.0);
	float beam = band(q.y, 0.0, 0.035 * (1.0 - 0.6 * age)) * (1.0 - smoothstep(1.0, 1.38, abs(q.x)));
	return mix(prism(q.x * 0.25 + p), vec3(1.0), 0.6) * beam * life * 1.3;
}

// The white flash at the impact. It builds through the last of the collapse, bursts at 0.25, and falls away quickly. It
// lights the hole's surroundings, and the caller keeps it off the black horizon.
vec3 flash_light(float r, float p) {
	float dt = p - 0.25;
	float level = dt < 0.0 ? 0.35 * smoothstep(0.16, 0.25, p) : exp(-dt * 14.0);
	return vec3(1.0, 0.97, 0.92) * level * exp(-r * r * 1.5);
}

// One dispersal shard: a short prismatic dash that leaves the ring at its own angle and speed, from 0.4 to 1.0 of the
// timeline (t runs 0 to 1 over that span).
vec3 shard_at(float cell, float ta, float r, float t) {
	float idx = mod(cell, SHARD_COUNT);
	float seed = hash1(idx);
	float centre = (idx + 0.2 + 0.6 * hash1(idx + 7.0)) / SHARD_COUNT;
	float across = (ta - centre) - floor(ta - centre + 0.5);
	float reach = PHOTON + (0.5 + 0.8 * seed) * t;
	float dash = smoothstep(reach - 0.14, reach, r) * (1.0 - smoothstep(reach, reach + 0.03, r));
	float body = band(across * TAU_F * r, 0.0, 0.012 + 0.012 * seed);
	return prism(centre + seed * 0.3) * dash * body * smoothstep(0.0, 0.1, t) * (1.0 - t) * 1.6;
}

// The dispersal: sixteen shards, one per sector. The three sectors that could reach a pixel are read.
vec3 shard_light(float ta, float r, float p) {
	float t = clamp((p - 0.4) / 0.6, 0.0, 1.0);
	float cell = floor(ta * SHARD_COUNT);
	return shard_at(cell - 1.0, ta, r, t) + shard_at(cell, ta, r, t) + shard_at(cell + 1.0, ta, r, t);
}

// The lensing pinch: the screen behind the hole is read from nearer its centre, so the background bends round the horizon
// and brightens at the rim. `uv` and `screen_uv` are the fragment's own UV and SCREEN_UV. The screen spans the quad at a
// scale the derivatives give, so the quad need not be known in pixels.
vec4 lensed_screen(vec2 q, vec2 uv, vec2 screen_uv, float amount) {
	float edge = 1.0 - smoothstep(0.9, 1.35, length(q));
	vec2 screen_per_uv = vec2(dFdx(screen_uv.x) / dFdx(uv.x), dFdy(screen_uv.y) / dFdy(uv.y));
	float bend = amount * 0.12 / (dot(q, q) + 0.12);
	vec3 behind = texture(screen_tex, screen_uv - (uv - 0.5) * screen_per_uv * bend).rgb;
	float cover = edge * min(amount * 1.5, 1.0);
	return vec4(behind * cover, cover);
}

void fragment() {
	float p = progress;
	float fade = 1.0 - smoothstep(0.82, 1.0, p);
	// q: the position in disc radii, centred on the hole, y down. r and ang are its polar form; ta is ang in turns.
	vec2 q = (UV - 0.5) / radius_uv;
	float r = length(q);
	float ang = atan(q.y, q.x);
	float ta = ang / TAU_F + 0.5;
	float spin_angle = reduced ? 0.0 : p * spin * 0.8 * TAU_F;
	float scan = scanlines ? 0.6 + 0.4 * sin(FRAGCOORD.y * 2.1) : 1.0;
	float gain = 0.25 * smoothstep(0.0, 0.12, p) + 0.75 * smoothstep(0.12, 0.25, p);
	// The horizon opens during the collapse, from nothing to its full radius.
	float hole_r = HORIZON * smoothstep(0.08, 0.25, p);
	float horizon = (1.0 - smoothstep(hole_r * 0.94, hole_r * 1.02 + 0.004, r)) * smoothstep(0.02, 0.08, p) * fade;
	float arc = cells ? ring_arcs(ta, p) : 1.0;

	vec3 glow = disc_light(q, spin_angle, gain * fade, scan);
	glow += photon_light(r, ang + spin_angle, p, arc) * fade;
	// Reduced motion drops the shock ring, as it drops the jets and the dispersal below (LEGENDARY_LOOKS.md, v3.3).
	if (!reduced) {
		glow += shock_light(r, ang, p) * fade;
	}
	if (jets && !reduced) {
		glow += jet_light(q, p) * fade;
	}
	// Reduced motion drops the inflow arms as well (LEGENDARY_LOOKS.md, v3.4). The node also sets arms to 0.
	if (arms > 0 && !reduced) {
		glow += arm_light(ta, r, p) * fade;
	}
	if (digits > 0) {
		glow += digit_light(ta, r, p) * fade;
	}
	if (split) {
		glow += split_light(q, p) * fade;
	}
	if (!reduced) {
		glow += shard_light(ta, r, p) * fade;
	}
	// The light fades out over the quad's outer margin (EDGE_FADE to QUAD_EDGE), so no border shows where the quad ends.
	float frame = 1.0 - smoothstep(EDGE_FADE, QUAD_EDGE, r);
	glow *= (1.0 - horizon) * frame;
	vec3 flash = flash_light(r, p) * fade * (1.0 - horizon) * frame;

	// The lens peaks at the impact (0.25) and is gone by 0.7. Reduced motion has no lens, so no screen read happens.
	float amount = reduced ? 0.0 : lens * smoothstep(0.0, 0.25, p) * (1.0 - smoothstep(0.25, 0.7, p));
	vec4 lensed = vec4(0.0);
	if (amount > 0.0) {
		lensed = lensed_screen(q, UV, SCREEN_UV, amount);
	}
	COLOR = vec4(lensed.rgb * (1.0 - horizon) + glow + flash, lensed.a * (1.0 - horizon) + horizon);
}
