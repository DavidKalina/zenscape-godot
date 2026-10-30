shader_type spatial;
// The burrower's ridge (scripts/burrower/burrower.gd): a strip laid on the
// ground along its path, heaved up from each sample's age. UV.x is across
// (-1..1), UV.y the half width (m), UV2 (born, strength), TANGENT the strip's
// side, COLOR the ground's colour there (sRGB). Ahead of the burrower the
// samples are born in the future: the bow rising before it.

uniform float now = 0.0;
// Peak heave (m), what it slumps to, the scar it settles to, the scar's life (s).
uniform float heave = 1.05;
uniform float settle = 0.5;
uniform float scar = 0.2;
uniform float life = 26.0;
// The bow's lead (s) and the heave's ring (decay per s, rad per s).
uniform float bow = 0.24;
uniform float ring_decay = 1.9;
uniform float ring_rate = 7.0;
uniform vec3 earth : source_color = vec3(0.27, 0.19, 0.12);
uniform vec3 earth_dry : source_color = vec3(0.42, 0.33, 0.22);

varying float v_torn;
varying float v_age;

float rise(float a) {
	if (a < 0.0) {
		float s = smoothstep(-bow, 0.0, a);
		return s * s;
	}
	float rest = mix(settle, scar, smoothstep(2.5, 16.0, a)) * (1.0 - smoothstep(life * 0.6, life, a));
	float r = rest + (1.0 - rest) * exp(-ring_decay * a) * cos(ring_rate * a);
	return max(r, rest * 0.35);
}

float hash1(float x) {
	return fract(sin(x * 91.7) * 43758.5453);
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void vertex() {
	float u = UV.x;
	float hw = UV.y;
	float born = UV2.x;
	float k = UV2.y;
	float a = now - born;
	v_age = a;
	float r = rise(a) * k;
	float lump = 0.8 + 0.4 * hash1(floor(born * 7.0));
	float b = 1.0 - u * u;
	b *= b;
	// The crest cracks open once the head is past: a narrow dip, torn earth.
	float open = smoothstep(0.03, 0.3, a) * k * (1.0 - smoothstep(life * 0.55, life, a));
	float rag = 0.1 * (hash1(born * 3.1 + u * 5.0) - 0.5);
	float crack = 1.0 - smoothstep(0.0, 0.3 + rag, abs(u));
	float lift = heave * r * lump * b - crack * open * 0.06 * min(r * 4.0, 1.0);
	VERTEX.y += lift;
	// The slope across from d(lift)/du.
	float slope = heave * r * lump * (-4.0 * u * (1.0 - u * u)) / max(hw, 0.1);
	NORMAL = normalize(NORMAL - TANGENT * slope);
	v_torn = clamp(open * (1.0 - smoothstep(0.1 + rag, 0.34 + rag, abs(u))) * 1.3, 0.0, 1.0);
}

void fragment() {
	vec3 turf = to_linear(COLOR.rgb);
	// Fresh earth dark and moist, drying paler as the scar settles.
	vec3 soil = mix(earth, earth_dry, smoothstep(2.0, 18.0, v_age));
	ALBEDO = mix(turf, soil, v_torn);
	ROUGHNESS = 0.95;
}
