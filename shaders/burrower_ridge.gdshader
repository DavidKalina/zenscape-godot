shader_type spatial;
#include "res://shaders/burrower_grit.gdshaderinc"
// The burrower's ridge (scripts/burrower/burrower.gd): a strip laid on the
// ground along its path, heaved up from each sample's age. UV.x is across
// (-1..1), UV.y the half width (m), UV2 (born, strength), TANGENT the strip's
// side, COLOR the ground's colour there (sRGB). Ahead of the burrower the
// samples are born in the future: the bow rising before it.

uniform float now = 0.0;
// Peak heave (m), what it slumps to, the scar it settles to, the scar's life (s).
uniform float heave = 1.05;
uniform float settle = 0.16;
uniform float scar = 0.05;
uniform float life = 26.0;
// The bow's lead (s) and the heave's ring (decay per s, rad per s).
uniform float bow = 0.24;
uniform float ring_decay = 3.4;
uniform float ring_rate = 7.0;
// The head: an extra heave at the head itself (times heave), how fast it
// falls off behind (per s), its churn (fraction, rad per s).
uniform float head = 1.1;
uniform float head_fall = 7.0;
uniform float churn = 0.3;
uniform float churn_rate = 13.0;
// The tail breaks up: stretches of BREAK_LEN s of travel, this share of them
// sinking almost flat soon after the head is past.
uniform float break_len = 0.3;
uniform float break_share = 0.45;
uniform vec3 earth : source_color = vec3(0.40, 0.29, 0.19);
uniform vec3 earth_dry : source_color = vec3(0.52, 0.43, 0.30);

varying float v_torn;
varying float v_age;
varying float v_head;
varying vec3 v_pos;

float hash1(float x) {
	return fract(sin(x * 91.7) * 43758.5453);
}

// The head's share of the heave at age a: 1 at the head, gone behind it.
float head_k(float a) {
	if (a < 0.0) return smoothstep(-bow, 0.0, a);
	return exp(-head_fall * a);
}

float rise(float a, float born) {
	if (a < 0.0) {
		float s = smoothstep(-bow, 0.0, a);
		return s * s;
	}
	// Broken stretches slump nearly flat a moment after the head is past.
	float brk = step(hash1(floor(born / break_len) + 17.0), break_share);
	float rest = mix(settle, scar, smoothstep(1.0, 6.0, a)) * (1.0 - smoothstep(life * 0.5, life, a));
	rest *= mix(1.0, 0.1, brk * smoothstep(0.12, 0.5, a));
	float fade = mix(1.0, 0.25, brk * smoothstep(0.12, 0.5, a));
	float r = rest + (1.0 - rest) * fade * exp(-ring_decay * a) * cos(ring_rate * a);
	return max(r, rest * 0.35);
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
	float hk = head_k(a);
	v_head = hk * k;
	// The head churns: its height kicks with time and from lump to lump.
	float ch = 1.0 + churn * (sin(now * churn_rate + born * 3.0) * 0.6 + sin(now * churn_rate * 1.7 + 1.3) * 0.4);
	float r = (rise(a, born) + head * hk * ch) * k;
	float lump = 0.8 + 0.4 * hash1(floor(born * 7.0));
	// Narrower and rounder at the head (a tall mound), the furrow's own shape behind.
	float uu = u * mix(1.0, 1.35, hk);
	float b = max(1.0 - uu * uu, 0.0);
	b *= b;
	// The crest cracks open once the head is past: a narrow dip, torn earth.
	float open = smoothstep(0.03, 0.3, a) * k * (1.0 - smoothstep(life * 0.55, life, a));
	float rag = 0.1 * (hash1(born * 3.1 + u * 5.0) - 0.5);
	float crack = 1.0 - smoothstep(0.0, 0.3 + rag, abs(u));
	float lift = heave * r * lump * b - crack * open * 0.06 * min(r * 4.0, 1.0);
	// Ragged, crumbly: the torn earth and the head's mound heaved unevenly.
	float rough = hash1(born * 11.3 + u * 7.7) - 0.4;
	lift += (v_head + 0.5 * open) * 0.1 * rough * b;
	VERTEX.y += lift;
	v_pos = VERTEX;
	// The slope across from d(lift)/du.
	float slope = heave * r * lump * (-4.0 * uu * max(1.0 - uu * uu, 0.0)) * mix(1.0, 1.35, hk) / max(hw, 0.1);
	NORMAL = normalize(NORMAL - TANGENT * slope);
	// Torn in patches (not an even band), and the head's crest bare earth.
	float ph = hash1(floor(born * 5.0) + 3.0);
	float brk = step(hash1(floor(born / break_len) + 17.0), break_share);
	float patchy = step(0.3, ph) * (0.5 + 0.7 * ph) * (1.0 - brk);
	float torn = open * patchy * (1.0 - smoothstep(0.1 + rag, 0.34 + rag, abs(u))) * 1.3;
	float crest = v_head * (1.0 - smoothstep(0.25 + rag, 0.7 + rag, abs(u)));
	v_torn = clamp(max(torn, crest * 0.95), 0.0, 1.0);
}

void fragment() {
	vec3 turf = to_linear(COLOR.rgb);
	// Fresh earth dark and moist, drying paler as the scar settles.
	vec3 soil = mix(earth, earth_dry, smoothstep(2.0, 18.0, v_age));
	// Gritty where torn: dry crumbs on damp dark earth, grains, root bits.
	float dry = smoothstep(2.0, 18.0, v_age);
	vec3 grit = grit_albedo(v_pos * 1.3, soil * 1.15, 0.2 + 0.6 * dry, 0.0);
	// A little grain in the turf too.
	vec3 grass = turf * (0.88 + 0.24 * g_noise(v_pos * 14.0));
	ALBEDO = mix(grass, grit, v_torn);
	ROUGHNESS = 0.97;
	if (v_torn > 0.05) {
		float h = grit_height(v_pos * 1.3, 0.0);
		vec3 dpdx = dFdx(VERTEX);
		vec3 dpdy = dFdy(VERTEX);
		vec3 r1 = cross(dpdy, NORMAL);
		vec3 r2 = cross(NORMAL, dpdx);
		float det = dot(dpdx, r1);
		vec3 gr = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
		NORMAL = normalize(abs(det) * NORMAL - v_torn * 0.02 * gr);
	}
}
