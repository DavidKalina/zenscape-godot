// The surge's shared reads: what the sea (shaders/endless_sea.gdshader) and
// the crests' spray (shaders/surge_spray.gdshader) both take from it, so the
// sea's breakers and the spray off them are one. The CPU's mirror is EndlessSea
// `surge_at`: change them together. Needs GRAVITY and the uniform
// swell_heading declared before it.

// A hash with no sine (so the CPU's mirror, EndlessSea, reads the same).
float zs_body_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float zs_body_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(zs_body_hash(i), zs_body_hash(i + vec2(1.0, 0.0)), f.x), mix(zs_body_hash(i + vec2(0.0, 1.0)), zs_body_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// The surge: the big swell round the edge of a world with one (EndlessSea
// `set_edge`; mirrored for the plane by EndlessSea `surge_at`). Three long
// waves over the sea's own, the first two with their fronts along the edge
// line (`surge_edge`: centre x, z, half side, corner radius; half 0 none), so
// they roll in toward the land on every side. They start `surge_belt.x` m past
// the line and are whole by `.y`, both pushed out by up to SURGE_REACH where
// a slow noise wanders, so the belt builds up on no one line. The sheet heaves
// with them out to `.z` m from the eye, fading by `.w`, and past that they are
// shading alone. Sets (crests
// rising and dying as they run in) and peaks along a crest keep them from
// reading as rings. `surge_size` scales their height, `surge_peak` how sharp
// the crests get. The two fronts lean toward the land (SURGE_LEAN: a steep face
// ahead of the crest, a long back behind it). `surge_break`: how tall a wave
// (m, trough to rest) starts to break, and is sure to.
uniform vec4 surge_edge = vec4(0.0);
uniform vec4 surge_belt = vec4(-200.0, 700.0, 2200.0, 3200.0);
uniform float surge_size = 1.0;
uniform float surge_peak = 0.85;
uniform vec2 surge_break = vec2(8.0, 13.0);
const float SURGE_LENGTH[3] = float[3](180.0, 130.0, 90.0);
const float SURGE_SIZE[3] = float[3](9.0, 5.0, 2.2);
const vec2 SURGE_SET = vec2(0.007, 0.059);
const float SURGE_LEAN = 0.35;
const float SURGE_CREST_LENGTH = 150.0;
const float SURGE_REACH = 700.0;
const float SURGE_WANDER = 2300.0;
const vec2 SURGE_BEND = vec2(14.0, -9.0);
const float SURGE_BEND_LENGTH = 1700.0;
const float SURGE_LIFT_FLOOR = 7.0;
const float SURGE_SEAM = 160.0;

// How far `p` lies past the edge line, and the way out from it there.
float zs_surge_off(vec2 p, out vec2 way_out) {
	vec2 rel = p - surge_edge.xy;
	vec2 q = abs(rel) - vec2(surge_edge.z - surge_edge.w);
	vec2 o = max(q, vec2(0.0));
	float len = length(o);
	vec2 n = len > 1e-3 ? o / len : (q.x > q.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0));
	way_out = n * vec2(rel.x < 0.0 ? -1.0 : 1.0, rel.y < 0.0 ? -1.0 : 1.0);
	return len + min(max(q.x, q.y), 0.0) - surge_edge.w;
}

// The surge at rest xz `p`: the shove and rise (`shift`), the sheet's squeeze
// (`jac`), how far up the wave this is (`lift`, 0 trough .. 1 crest), how
// whole the belt is (`share`), what the foam reads (`crest`: the two fronts as
// one wave, its height and quarter-turn-on height, and the crossing wave's
// height, all at any distance) and the slope of the displaced sheet (returned).
vec2 zs_surge(vec2 p, float t, float footprint, out vec3 shift, out float jac, out float lift, out float share, out vec3 crest) {
	shift = vec3(0.0);
	jac = 1.0;
	lift = 0.5;
	share = 0.0;
	crest = vec3(0.0);
	vec2 way_out;
	float off = zs_surge_off(p, way_out);
	if (off <= surge_belt.x) return vec2(0.0);
	// Where the belt builds up wanders out along the coast (SURGE_REACH), so
	// it starts on no one line round the land.
	float wander = smoothstep(0.2, 0.8, zs_body_noise(p / SURGE_WANDER + vec2(5.3, 2.6)));
	share = smoothstep(surge_belt.x, surge_belt.y, off - wander * SURGE_REACH);
	if (share <= 0.0) return vec2(0.0);
	float warp_a = zs_body_noise(p / 900.0 + vec2(3.7, 1.9));
	float warp_b = zs_body_noise(p / 560.0 + vec2(6.1, 8.3));
	// The two fronts bend apart over kilometres (SURGE_BEND), so the crests
	// cross a little and no two rows run alike.
	float bend = zs_body_noise(p / SURGE_BEND_LENGTH + vec2(1.4, 7.7)) - 0.5;
	float sets = 0.5 + 0.5 * sin(-off * SURGE_SET.x - t * SURGE_SET.y + warp_a * 5.0);
	// Peaks along a crest, and stretches of crest a few hundred metres long
	// that run low, so a far row is no unbroken line.
	float lobe = smoothstep(0.3, 0.7, zs_body_noise(p / 260.0 + vec2(t * 0.012, 4.2)) * 0.55 + zs_body_noise(p / 640.0 + vec2(8.2, t * 0.006)) * 0.45);
	float grown = (0.4 + 0.6 * sets) * (0.6 + 0.8 * lobe);
	float size = surge_size * share * grown;
	vec2 d[3];
	d[0] = -way_out;
	d[1] = -way_out;
	d[2] = normalize(swell_heading);
	float ks[3], omega[3], amps[3], phases[3];
	float total = 0.0;
	for (int i = 0; i < 3; i++) {
		ks[i] = TAU / SURGE_LENGTH[i];
		omega[i] = sqrt(GRAVITY * ks[i]);
		amps[i] = SURGE_SIZE[i] * size;
		total += amps[i] * ks[i];
	}
	phases[0] = -off * ks[0] - omega[0] * t + warp_a * 2.6 + bend * SURGE_BEND.x;
	phases[1] = -off * ks[1] - omega[1] * t + warp_b * 3.4 + 2.39 + bend * SURGE_BEND.y;
	phases[2] = dot(p, d[2]) * ks[2] - omega[2] * t + warp_a * 1.5 + 4.78;
	float q = surge_peak / max(total, 0.2);
	vec2 slope = vec2(0.0);
	vec3 j = vec3(1.0, 1.0, 0.0);
	for (int i = 0; i < 3; i++) {
		float held = 1.0 - smoothstep(SURGE_LENGTH[i] * 0.1, SURGE_LENGTH[i] * 0.28, footprint);
		float lean = i < 2 ? SURGE_LEAN : 0.0;
		float bent = phases[i] - lean * sin(phases[i]);
		float cp = cos(bent), sp = sin(bent);
		float steep = amps[i] * ks[i] * (1.0 - lean * cos(phases[i]));
		shift.xz += d[i] * q * amps[i] * cp * held;
		shift.y += amps[i] * sp * held;
		slope += d[i] * steep * cp * held;
		j -= vec3(d[i].x * d[i].x, d[i].y * d[i].y, d[i].x * d[i].y) * q * steep * sp * held;
		if (i < 2) crest.xy += amps[i] * vec2(sp, cp);
		else crest.z = amps[i] * sp;
	}
	jac = j.x * j.y - j.z * j.z;
	// Measured against this wave's own size: a set's tall crests saturate no
	// sooner than its small ones, so the glow stays up at the crest. Not below
	// SURGE_LIFT_FLOOR m, so low stretches read low: from far off every row
	// glowing alike read as ruled lines.
	lift = smoothstep(-1.0, 1.0, shift.y / max(11.0 * size, SURGE_LIFT_FLOOR));
	float det = max(jac, 0.1);
	return vec2(j.y * slope.x - j.z * slope.y, j.x * slope.y - j.z * slope.x) / det;
}

// The sections a crest breaks in, `along` it and `slip` past the line.
float zs_surge_sections(float along, float slip) {
	return zs_body_noise(vec2(along / 85.0, slip / 240.0) + vec2(3.1, 0.7)) * 0.65 + zs_body_noise(vec2(along / 31.0, slip / 120.0) + vec2(7.4, 2.9)) * 0.35;
}

// `along` (zs_surge_breaks) wraps once round the edge: how much of the read
// from the far side of the wrap (zs_surge_across) to blend in (0 .. 0.5 on it).
float zs_surge_seam(float along) {
	float half_round = PI * surge_edge.z;
	return 0.5 * smoothstep(half_round - SURGE_SEAM, half_round, abs(along));
}

float zs_surge_across(float along) {
	return along - sign(along) * TAU * surge_edge.z;
}

// How hard the surge breaks at rest xz `p`, from `crest` (zs_surge): 0 calm ..
// 1 white water. Only tall waves break, in sections along the crest that ride
// with it. Also how far past the edge line `p` is (`off`), how far round it
// (`along`, m; seam on the SW diagonal) and how far behind the crest (`back`,
// m; ahead of it below 0).
float zs_surge_breaks(vec2 p, float t, vec3 crest, out float off, out float along, out float back) {
	off = 0.0;
	along = 0.0;
	back = 0.0;
	float tall = length(crest.xy) + max(crest.z, 0.0) * 0.6;
	float over = (tall - surge_break.x) / max(surge_break.y - surge_break.x, 0.1);
	if (over < -0.8) return 0.0;
	vec2 way_out;
	off = zs_surge_off(p, way_out);
	vec2 rel = p - surge_edge.xy;
	along = atan(rel.y - rel.x, rel.y + rel.x) * surge_edge.z;
	float behind = (PI * 0.5 - atan(crest.x, crest.y)) / TAU;
	if (behind > 0.5) behind -= 1.0;
	back = behind * SURGE_CREST_LENGTH;
	// A section breaks for as long as the crest stays on it: the crest slips
	// slowly through the pattern, and what lies on the back is what it was
	// when the crest went by.
	float speed = sqrt(GRAVITY * SURGE_CREST_LENGTH / TAU);
	float slip = off + speed * t * 0.7 - max(back, 0.0) * 0.7;
	float sections = zs_surge_sections(along, slip);
	// Where `along` wraps round (the SW diagonal) read it both ways and blend,
	// so no breaker is cut there.
	float seam = zs_surge_seam(along);
	if (seam > 0.0) sections = mix(sections, zs_surge_sections(zs_surge_across(along), slip), seam);
	return smoothstep(0.0, 0.55, over + (sections - 0.5) * 2.2);
}
