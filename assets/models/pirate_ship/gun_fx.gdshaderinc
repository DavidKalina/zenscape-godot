// Shared by the pirate ship's gun shaders (gun_burst_solid, gun_burst_soft,
// gun_trail; scripts/endless/ship_guns.gd): how a bit of a burst moves, and
// the light on a ball of smoke, water or dust drawn as a disc turned to the
// eye, in the clouds' own colours (cumulus_light), so it follows the hour as
// the clouds do.
#include "res://shaders/cumulus_light.gdshaderinc"

// A burst's bit (ShipGuns `Burst`): every corner of a disc at its start
// (VERTEX), UV the corner,
//   CUSTOM0  its throw (m/s, the node's frame), its delay (s)
//   CUSTOM1  its life (s), drag (1/s), fall (m/s², down in the world), seed
//   CUSTOM2  its radius at the start and at the end (m), opacity, role
//   CUSTOM3  hardness (0 soft .. 1 a clean edge), glow (light through it),
//            wind (how much it drifts on it), spare
// The node sets, per instance: its age (s), `tall` (the throw up scaled by
// its root, so a column stands `tall` as high), `lean` (m/s along the world
// per m/s thrown up: a slanted column) and `dirt` (1: thrown off land).
// The wind's push on smoke and mist (m/s): the field's way, a breeze at calm.
vec3 gun_fx_wind() {
	vec2 wd = normalize(zs_wind_direction + vec2(1e-4, 0.0));
	return vec3(wd.x, 0.0, wd.y) * (1.2 + 3.5 * clamp(zs_wind_strength, 0.0, 1.5));
}

#ifdef GUN_BURST
const float GUN_BLOB = 0.0;
const float GUN_FLASH = 1.0;
const float GUN_DROP = 2.0;
const float GUN_RING = 3.0;
const float GUN_PATCH = 4.0;

instance uniform float age = 100.0;
instance uniform float tall = 1.0;
instance uniform vec3 lean = vec3(0.0);
instance uniform float dirt = 0.0;

varying vec2 v_q;
varying float v_alpha;
varying float v_role;
varying float v_seed;
varying float v_hard;
varying float v_glow;
varying float v_u;
varying vec3 v_tint;

// Where a bit of a burst is (world) and how fast it goes, `t` s after it set
// off from `p0` at `v0` (both in the node's frame, `model`), slowed by `drag`,
// falling at `fall` (world down), drifting `wind` of the wind.
vec3 gun_fx_path(mat4 model, vec3 p0, vec3 v0, float drag, float fall, float wind, float t, out vec3 vel) {
	float k = max(drag, 0.05);
	float e = exp(-k * t);
	float f = (1.0 - e) / k;
	float h = (t - f) / k;
	vec3 at = (model * vec4(p0 + v0 * f, 1.0)).xyz;
	at.y -= fall * h;
	at += gun_fx_wind() * wind * t;
	vel = mat3(model) * (v0 * e) - vec3(0.0, fall * f, 0.0) + gun_fx_wind() * wind;
	return at;
}

// One burst's bit, as the vertex stage sees it: the disc's corner `q` turned
// to the eye (or laid flat on the node's floor for a ring or a patch), grown,
// faded, stretched along its way if a drop. Returns the view-space point;
// `alpha` 0 for a bit not yet thrown or done, `u` its share of its life.
vec3 gun_fx_bit(mat4 model, mat4 view, vec3 p0, vec2 q, vec4 c0, vec4 c1, vec4 c2, vec4 c3, out float alpha, out float u) {
	float role = c2.w;
	float life = c1.x;
	vec3 v0 = c0.xyz;
	float up = sqrt(max(tall, 0.05));
	bool thrown = c1.z > 4.0;
	if (thrown) {
		// Water and clods: the column's height by `tall`, slanted by `lean`.
		v0.y *= up;
		v0 += (inverse(mat3(model)) * lean) * max(v0.y, 0.0);
		life *= up;
	} else {
		p0.y *= tall;
	}
	float t = age - c0.w;
	u = clamp(t / life, 0.0, 1.0);
	alpha = 0.0;
	if (t < 0.0 || t >= life) return vec3(0.0, 0.0, 1e6);
	bool lying = role == GUN_RING || role == GUN_PATCH;
	if (lying && dirt > 0.5) return vec3(0.0, 0.0, 1e6);
	float grow = 1.0 - pow(1.0 - u, 2.2);
	float r = mix(c2.x, c2.y, grow);
	vec3 vel;
	vec3 at = gun_fx_path(model, p0, v0, c1.y, c1.z, c3.z, t, vel);
	alpha = c2.z;
	if (lying) return (view * vec4(at + vec3(q.x * r, 0.0, q.y * r), 1.0)).xyz;
	if (thrown) r *= 1.0 - smoothstep(0.78, 1.0, u);
	vec3 centre = (view * vec4(at, 1.0)).xyz;
	vec2 off = q * r;
	if (role == GUN_DROP) {
		vec2 way = (mat3(view) * vel).xy;
		float len = length(way);
		if (len > 0.5) {
			way /= len;
			vec2 across = vec2(-way.y, way.x);
			float stretch = 1.0 + clamp(len * 0.045, 0.0, 2.6);
			off = across * q.x * r + way * q.y * r * stretch;
		}
	}
	return centre + vec3(off, 0.0);
}

#endif

// A disc's lumpy edge at polar angle `a`: overlapping discs read as one body.
float gun_fx_reach(float a, float seed) {
	return 0.9 + 0.1 * sin(a * 3.0 + seed * 6.3) * sin(a * 2.0 - seed * 12.6);
}

// The light on a ball at the disc's point `q` (-1..1, y up on screen), seen
// along `rd` (world), `inv_view` the view's basis, as values (a ball of smoke or
// water is near white or gray; the clouds' gold would brown it): x the sky's,
// y the sun's, both at this hour (cumulus_light) and at ZS_CUMULUS_LIT_SHARE;
// `side` how far round toward the sun the point faces (0 away .. 1 on).
vec2 gun_fx_light(vec2 q, mat3 inv_view, vec3 rd, out float side) {
	float z = sqrt(max(1.0 - dot(q, q), 0.0));
	vec3 n = normalize(inv_view * vec3(q, z));
	vec3 sun = normalize(zs_sun_direction + vec3(0.0, 1e-4, 0.0));
	vec3 hue;
	vec3 c_sun;
	vec3 c_shade;
	float lining;
	zs_cumulus_palette(rd, sun, hue, c_sun, c_shade, lining);
	float day = smoothstep(-0.08, 0.12, sun.y);
	side = clamp(dot(n, sun) * 0.5 + 0.5, 0.0, 1.0);
	vec3 luma = vec3(0.3, 0.6, 0.1);
	float sky = dot(c_shade, luma) * (0.55 + 0.45 * clamp(n.y * 0.5 + 0.5, 0.0, 1.0));
	return vec2(sky, dot(c_sun, luma) * day * (1.0 + lining)) * ZS_CUMULUS_LIT_SHARE;
}
