#ifndef ZS_RAIL_TIMBER_INC
#define ZS_RAIL_TIMBER_INC
// The railroad's timber (scripts/endless/rail_span.gd): sawn members whose
// UV runs u along the member and v across the face, in metres. Brought in
// through folk_surface.gdshaderinc with ZS_TIMBER_GRAIN, on top of the
// vertex colour (each member's own tone):
//   - the grain: streaks drawn out along the member, two scales,
//   - checks: thin dark splits along it,
//   - broad tone over a member's length (sun and rain unevenly),
//   - the fine parts faded by pixel footprint so it never shimmers.
// `grain` 0 leaves the colour flat.
uniform float grain : hint_range(0.0, 2.0) = 1.0;

float tg_hash(vec2 p) {
	p = fract(p * vec2(0.3183099, 0.3678794) + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * (p.x + p.y));
}

float tg_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(tg_hash(i), tg_hash(i + vec2(1.0, 0.0)), f.x),
		mix(tg_hash(i + vec2(0.0, 1.0)), tg_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void timber_grain(inout vec3 base, vec2 uv) {
	if (grain <= 0.0) return;
	float fw = max(fwidth(uv.y), 1e-4);
	float fine = 1.0 - smoothstep(0.015, 0.06, fw);
	float mid = 1.0 - smoothstep(0.05, 0.2, fw);
	float broad = tg_noise(vec2(uv.x * 0.18, uv.y * 0.9) + 7.3);
	float streak = tg_noise(vec2(uv.x * 0.35, uv.y * 7.0));
	float line = tg_noise(vec2(uv.x * 1.2 + 3.1, uv.y * 28.0));
	float check = smoothstep(0.86, 0.95, tg_noise(vec2(uv.x * 0.22 + 1.7, uv.y * 16.0 + 4.0)));
	float k = 1.0 + (broad - 0.5) * 0.28 + (streak - 0.5) * 0.3 * mid + (line - 0.5) * 0.22 * fine;
	base *= mix(1.0, k, grain);
	base *= 1.0 - 0.38 * check * mid * grain;
}
#endif
