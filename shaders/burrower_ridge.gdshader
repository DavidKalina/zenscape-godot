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
varying float v_u;
varying float v_born;

float hash1(float x) {
	return fract(sin(x * 91.7) * 43758.5453);
}

// Smooth 1D value noise, 0..1.
float vn1(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash1(i), hash1(i + 1.0), f);
}

// How broken the tail is at this travel: smooth and uneven in length (no regular
// dashes), 0 whole .. 1 slumped.
float broken(float born) {
	float n = vn1(born * 1.9 + 4.0) * 0.6 + vn1(born * 5.3 + 11.0) * 0.4;
	return smoothstep(0.5, 0.72, n);
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
	float brk = broken(born);
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
	float ph = vn1(born * 3.3 + 3.0) * 0.65 + vn1(born * 9.1 + u * 2.0) * 0.35;
	float brk = broken(born);
	float patchy = smoothstep(0.3, 0.55, ph) * (0.6 + 0.7 * ph) * (1.0 - brk);
	float torn = open * patchy * (1.0 - smoothstep(0.1 + rag, 0.34 + rag, abs(u))) * 1.3;
	v_u = u;
	v_born = born;
	float crest = v_head * (1.0 - smoothstep(0.25 + rag, 0.7 + rag, abs(u)));
	v_torn = clamp(max(torn, crest * 0.95), 0.0, 1.0);
}

void fragment() {
	vec3 turf = to_linear(COLOR.rgb);
	// Fresh earth dark and moist, drying paler as the scar settles.
	vec3 soil = mix(earth, earth_dry, smoothstep(2.0, 18.0, v_age));
	// Gritty where torn: dry crumbs on damp dark earth, grains, root bits.
	float dry = smoothstep(2.0, 18.0, v_age);
	// Lifted 1.45 so the grit's mean (damp earth 0.62 of it) stays near the
	// earth colour the head read with from the chase camera.
	vec3 grit = grit_albedo(v_pos * 1.3, soil * 1.45, 0.2 + 0.6 * dry, 0.0);
	// A little grain in the turf too.
	// Dry patches and a mottle, as the drawn ground has, so the strip belongs to it.
	float patch_n = g_noise(vec3(v_pos.x, 0.0, v_pos.z) * 0.11);
	// Dry ground (low meadow in COLOR.a) leans straw, as the drawn turf does.
	float lum = dot(turf, vec3(0.3, 0.55, 0.15));
	turf = mix(turf, lum * vec3(1.35, 1.1, 0.55), (1.0 - COLOR.a) * 0.9);
	vec3 dry_tint = vec3(0.30, 0.25, 0.12);
	turf = mix(turf, dry_tint * (0.85 + 0.3 * patch_n), smoothstep(0.45, 0.7, patch_n) * 0.35);
	vec3 grass = turf * (0.86 + 0.28 * g_noise(v_pos * 9.0));
	ALBEDO = mix(grass, grit, v_torn);
	ROUGHNESS = 0.97;
	// A torn, ragged outline instead of a hard strip: the rim and the far ends
	// (the lived-out tail, the bow's start) break up in grit-sized bites.
	float rim = 1.0 - smoothstep(0.55, 0.98, abs(v_u));
	float tail = 1.0 - smoothstep(life * 0.8, life * 0.98, v_age);
	float bite = g_noise(v_pos * 4.0) * 0.6 + g_noise(v_pos * 13.0) * 0.4;
	float edge = rim * tail * mix(0.5, 1.0, max(v_torn, 0.0));
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA = clamp(edge * 1.25 - bite * 0.55 + 0.1, 0.0, 1.0);
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
