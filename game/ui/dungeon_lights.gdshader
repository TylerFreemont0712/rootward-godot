shader_type canvas_item;

uniform float clock = 0.0;
uniform float movement = 1.0;
uniform int ring = 3;
uniform bool shaft = false;
uniform vec4 lamp_0;
uniform vec4 lamp_1;
uniform vec4 lamp_2;
uniform vec4 lamp_3;
varying vec4 canvas_tint;

void vertex() {
	canvas_tint = COLOR;
}

float pool(vec2 uv, vec4 lamp) {
	vec2 d = (uv - lamp.xy) / max(lamp.zw, vec2(0.001));
	return exp(-dot(d, d) * 2.0);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float drip(vec2 uv, vec2 origin, float offset) {
	float phase = fract(clock / 4.8 + offset);
	vec2 at = origin + vec2(0.0, phase * 0.13);
	vec2 d = (uv - at) / vec2(0.0018, 0.009);
	return exp(-dot(d, d) * 2.0) * sin(phase * 3.14159);
}

void fragment() {
	vec4 painted = texture(TEXTURE, UV);
	float t = clock;
	float lanterns = pool(UV, lamp_0) * (sin(t * 2.1) * 0.055 + sin(t * 4.3) * 0.018);
	lanterns += pool(UV, lamp_1) * (sin(t * 1.7 + 2.0) * 0.05 + sin(t * 3.9) * 0.016);
	lanterns += pool(UV, lamp_2) * (sin(t * 2.3 + 4.0) * 0.05 + sin(t * 4.7) * 0.02);
	lanterns += pool(UV, lamp_3) * sin(t * 1.9 + 1.0) * 0.05;
	vec3 light = painted.rgb * lanterns;
	float rear = (1.0 - smoothstep(0.61, 0.72, UV.y)) * smoothstep(0.05, 0.25, UV.y);

	// Slow translucent air stays in the rear recesses, clear of the combat floor.
	vec2 air = UV * vec2(12.0, 6.0) + vec2(t * 0.025, -t * 0.012);
	float mist = smoothstep(0.53, 0.87, noise(air));
	float vent = pool(UV, vec4(shaft ? 0.84 : 0.83, 0.45, 0.13, 0.21));
	light += vec3(0.13, 0.12, 0.10) * mist * vent * rear * 0.22;

	// A few motes settle through the shaft; they do not cover fighters or their name plates.
	for (int i = 0; i < 9; i++) {
		float seed = float(i);
		vec2 at = vec2(0.29 + fract(seed * 0.618) * 0.40,
			0.13 + fract(seed * 0.381 + t * (0.007 + seed * 0.0004)) * 0.45);
		at.x += sin(t * 0.21 + seed) * 0.004;
		vec2 d = (UV - at) / vec2(0.0007, 0.0012);
		float mote = exp(-dot(d, d) * 2.0);
		light += vec3(0.65, 0.43, 0.19) * mote * 0.26;
	}

	if (ring == 2) {
		vec2 leak = shaft ? vec2(0.86, 0.36) : vec2(0.80, 0.46);
		float water = drip(UV, leak, 0.0) + drip(UV, leak + vec2(0.014, 0.045), 0.47);
		float seam = pool(UV, vec4(leak.x, leak.y + 0.08, 0.025, 0.11));
		light += vec3(0.10, 0.49, 0.43) * (water * 0.48 + seam * (0.018 + 0.012 * sin(t * 0.7)));
	} else if (ring == 1) {
		for (int i = 0; i < 3; i++) {
			float phase = t * 0.65 - float(i) * 1.7;
			vec2 lamp = shaft ? vec2(0.88, 0.48 + float(i) * 0.023) : vec2(0.517 + float(i) * 0.028, 0.287);
			float signal = pow(max(0.0, sin(phase)), 3.0);
			light += vec3(0.46, 0.17, 0.02) * pool(UV, vec4(lamp, 0.012, 0.022)) * signal * 0.38;
		}
	} else if (ring == 0) {
		vec2 core = shaft ? vec2(0.16, 0.77) : vec2(0.50, 0.425);
		light += vec3(0.42, 0.31, 0.09) * pool(UV, vec4(core, 0.042, 0.072)) * sin(t * 0.55) * 0.11;
		float packet = exp(-pow((UV.y - (0.06 + fract(t * 0.065) * 0.30)) / 0.018, 2.0));
		float root = exp(-pow((UV.x - 0.47) / 0.005, 2.0));
		light += vec3(0.43, 0.31, 0.10) * packet * root * 0.16;
	}

	// Map layers share a shaft; only the patina and rear atmosphere change, without recolouring the route UI.
	if (shaft) {
		vec3 patina = ring == 2 ? vec3(0.84, 0.99, 0.97) :
			(ring == 1 ? vec3(1.0, 0.88, 0.76) : (ring == 0 ? vec3(0.83, 0.87, 0.93) : vec3(1.0)));
		painted.rgb *= patina;
	}
	COLOR = vec4(painted.rgb + light * movement, painted.a) * canvas_tint;
}
