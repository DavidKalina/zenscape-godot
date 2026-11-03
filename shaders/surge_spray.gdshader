shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, world_vertex_coords;
// Spray off the surge's breaking crests (scripts/endless/surge_spray.gd): cards
// round the eye in three rings (near small, far big), each one reborn every few
// seconds at a hashed point, moved forward onto the nearest crest and kept only
// if the crest breaks there (zs_surge_breaks, the test the sea's foam makes).
// It runs in with the crest on its lip for its whole life, streaming back off
// it on the air past the crest a few metres, climbing a little and thinning
// out: white water torn off the lip, never a puff left over the sea. Nothing here touches the CPU: the
// cards' points come from the sea's clock and the eye alone.
#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/cumulus_light.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
const float GRAVITY = 9.81;
uniform vec2 swell_heading = vec2(0.8, 0.6);
#include "res://shaders/endless_surge.gdshaderinc"

// Vertex attributes (SurgeSpray):
//   UV       the card's corner (-1..1)
//   CUSTOM0  the ring's tile (m), shown from, gone by (m from the eye), card size (m)
//   CUSTOM1  seeds (phase 0..1, id), life (s), how far it climbs (m)

uniform float sea_y = -40.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D cloud_shape : hint_default_black, filter_nearest, repeat_disable;
uniform vec4 haze = vec4(120.0, 7600.0, 0.75, 0.8);
uniform float haze_height = 650.0;
uniform float haze_share = 0.45;
// How thick a plume is at its fullest.
uniform float opacity = 0.9;
// The wind's speed at zs_wind_strength 0 and per unit of it (m/s).
uniform vec2 wind_speed = vec2(4.0, 6.0);
// How bright the white is against the lit cloud's value.
uniform float spray_white = 1.3;

// How soon the spray torn off the lip has lost the crest's way and taken the
// air's (s): the plume keeps this close to the lip.
const float TEAR = 0.55;
// How soon it has climbed most of its way (s).
const float CLIMB = 0.45;
// Fades against the water and the land over this (m), and near the eye.
const float SOFT = 4.0;
const vec2 NEAR = vec2(6.0, 22.0);

varying vec2 v_uv;
varying float v_show;
varying flat float v_seed;
varying float v_age;

void vertex() {
	v_uv = UV;
	v_seed = CUSTOM1.y;
	v_show = 0.0;
	v_age = 0.0;
	float tile = CUSTOM0.x;
	float life = CUSTOM1.z;
	float t = zs_flow_time;
	float clock = t / life + CUSTOM1.x;
	float n = floor(clock);
	float age = fract(clock);
	float s = age * life;
	vec3 cam = MAIN_CAM_INV_VIEW_MATRIX[3].xyz;
	// This life's point: a hash in the tile, the copy of it nearest the eye.
	vec2 u = vec2(zs_body_hash(vec2(CUSTOM1.y * 0.37 + 1.7, n * 1.31 + 0.5)), zs_body_hash(vec2(n * 0.73 + 3.3, CUSTOM1.y * 0.59 + 8.1)));
	vec2 b = u * tile;
	vec2 w0 = b + tile * floor((cam.xz - b) / tile + 0.5);
	// The copy jumps a tile as the eye moves on: gone before it does.
	vec2 apart = abs(w0 - cam.xz);
	float kept = 1.0 - smoothstep(0.42, 0.48, max(apart.x, apart.y) / tile);
	vec2 way_out;
	float off0 = zs_surge_off(w0, way_out);
	vec3 pos = vec3(0.0);
	if (surge_edge.z > 0.0 && off0 > surge_belt.x && kept > 0.0) {
		vec3 shift, crest;
		float jac, lift, share;
		float crest_speed = sqrt(GRAVITY * SURGE_CREST_LENGTH / TAU);
		// The point runs in with the crests, so it keeps to the crest it was born
		// by, and is moved onto that crest's lip now: the spray goes where the
		// crest goes and stops where it stops breaking.
		vec2 w = w0 - way_out * crest_speed * s;
		zs_surge(w, t, 0.0, shift, jac, lift, share, crest);
		float behind = (PI * 0.5 - atan(crest.x, crest.y)) / TAU;
		if (behind > 0.5) behind -= 1.0;
		// Halfway between two crests the nearest one changes: hidden there.
		float held = 1.0 - smoothstep(0.34, 0.44, abs(behind));
		w -= way_out * behind * SURGE_CREST_LENGTH;
		zs_surge(w, t, 0.0, shift, jac, lift, share, crest);
		float off, along, back;
		float breaks = zs_surge_breaks(w, t, crest, off, along, back);
		w -= way_out * back;
		float tall = length(crest.xy);
		float from_eye = length(w - cam.xz);
		// The sea's heave fades with distance from the eye; so does this.
		float heave = 1.0 - smoothstep(surge_belt.z, surge_belt.w, from_eye);
		vec3 lip = vec3(w.x + shift.x * heave, sea_y + shift.y * heave, w.y + shift.z * heave);
		vec2 wd = normalize(zs_wind_direction + vec2(1e-4, 0.0));
		float gust = wind_speed.x + wind_speed.y * clamp(zs_wind_strength, 0.0, 1.5);
		// The air past the crest, as the crest sees it: the plume streams back
		// off the lip on it, a few metres, and climbs a little.
		vec2 air = wd * gust + way_out * crest_speed;
		vec2 drift = air * TEAR * (1.0 - exp(-s / TEAR));
		float climb = CUSTOM1.w * (0.5 + 0.5 * smoothstep(0.0, 1.0, (tall - surge_break.x) / 8.0)) * (1.0 - exp(-s / CLIMB));
		vec3 torn = vec3(drift.x, climb, drift.y);
		// Where the eye judges the curtain from: halfway up it.
		vec3 at = lip + torn * 0.5;
		// A curtain along the crest, as the eye sees it: its width along the
		// lip, its height up off it and back with the air. Seen along the crest
		// it turns to face the eye.
		vec3 along_lip = vec3(-way_out.y, 0.0, way_out.x);
		vec3 look = normalize(at - cam);
		vec3 a = along_lip - look * dot(along_lip, look);
		float la = length(a);
		vec3 right = MAIN_CAM_INV_VIEW_MATRIX[0].xyz;
		a = la > 1e-3 ? mix(right, a / la, smoothstep(0.15, 0.5, la)) : right;
		a = normalize(a - look * dot(a, look));
		vec3 up = cross(look, a);
		if (up.y < 0.0) up = -up;
		float size = CUSTOM0.w * (0.6 + 0.7 * age);
		float from = length(at.xz - cam.xz);
		float ring = smoothstep(CUSTOM0.y * 0.8, CUSTOM0.y, from) * (1.0 - smoothstep(CUSTOM0.z * 0.8, CUSTOM0.z, from));
		if (CUSTOM0.y <= 0.0) ring = 1.0 - smoothstep(CUSTOM0.z * 0.8, CUSTOM0.z, from);
		float lived = smoothstep(0.0, 0.15, age) * (1.0 - smoothstep(0.4, 0.95, age));
		v_show = breaks * share * ring * lived * held * kept * (1.0 - smoothstep(6.0, 14.0, abs(back)));
		v_age = age;
		// Its foot held on the lip, a little under the water, which hides it; its
		// top torn back and up off it, so it never leaves the crest.
		float h = UV.y * 0.5 + 0.5;
		pos = lip + torn * h + a * UV.x * size * 1.1 + up * (UV.y + 0.85) * size * 0.6;
	}
	if (v_show < 0.004) pos = vec3(0.0);
	VERTEX = pos;
}

void fragment() {
	if (v_show < 0.004) discard;
	float t = length(VERTEX);
	vec3 eye = CAMERA_POSITION_WORLD;
	vec3 rd = mat3(INV_VIEW_MATRIX) * (VERTEX / t);
	float soft = 1.0;
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	if (depth > 1e-6) {
		vec4 up = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
		soft = smoothstep(0.0, SOFT, length(up.xyz / up.w) - t);
	}
	if (soft <= 0.0) discard;
	vec2 q = v_uv;
	// A curtain off the lip: dense at its foot, torn into strands that stream
	// up and back off it, a ragged top that rises as it goes, thinning out.
	float xs = abs(q.x);
	float ys = q.y * 0.5 + 0.5;
	vec2 g = vec2(q.x * 1.6, ys * 0.7 - v_age * 0.8) + vec2(v_seed * 7.31, v_seed * 3.17);
	float n2 = zs_body_noise(g * vec2(3.1, 1.4) + vec2(4.1, 1.7));
	float n = zs_body_noise(g) * 0.5 + n2 * 0.32 + zs_body_noise(g * vec2(7.0, 2.5) + vec2(1.3, 8.4)) * 0.18;
	float top = (0.35 + 0.65 * zs_body_noise(vec2(q.x * 2.2 + v_seed * 5.1, v_seed * 2.3))) * (0.55 + 0.45 * v_age);
	float env = smoothstep(0.0, 0.1, ys) * (1.0 - smoothstep(top * 0.4, top, ys)) * (1.0 - smoothstep(0.45, 1.0, xs + 0.25 * (n2 - 0.5)));
	float shape = env * (0.25 + 1.2 * n) * (1.0 - 0.5 * ys) * (1.0 - 0.4 * v_age);
	float a = pow(clamp(shape, 0.0, 1.0), 1.4) * v_show * opacity;
	a *= soft * smoothstep(NEAR.x, NEAR.y, t);
	if (a < 0.003) discard;

	vec3 sun = normalize(zs_sun_direction + vec3(0.0, 1e-4, 0.0));
	vec3 sun_hue;
	vec3 c_sun;
	vec3 c_shade;
	float lining;
	zs_cumulus_palette(rd, sun, sun_hue, c_sun, c_shade, lining);
	float toward_sun = max(dot(rd, sun), 0.0);
	float high = smoothstep(0.02, 0.4, sun.y);
	// Fine water: white, the sun through it bright, cool where it is thin.
	float thick = smoothstep(0.1, 0.8, shape);
	vec3 lit = 1.0 * c_shade * mix(0.35, 1.0, high) + (1.05 + 0.35 * thick + lining + 1.6 * pow(toward_sun, 6.0)) * c_sun;
	lit *= ZS_CUMULUS_LIT_SHARE;
	// White water, as the surge's foam is (endless_sea surge_white): neutral at
	// the same value and a little brighter, not the clouds' warm lining.
	lit = vec3(0.97, 0.99, 1.0) * dot(lit, vec3(0.3, 0.6, 0.1)) * spray_white;
	lit = mix(lit, lit * vec3(0.88, 0.95, 1.04), 1.0 - thick);

	// The haze between, the cloud sheet's: by distance, thinner the higher.
	float y0 = max(eye.y - sea_y, 0.0);
	float y1 = max(eye.y + rd.y * t - sea_y, 0.0);
	float climb = y1 - y0;
	float airmass = abs(climb) > 1.0 ? haze_height * (exp(-y0 / haze_height) - exp(-y1 / haze_height)) / climb : exp(-y0 / haze_height);
	float dist = t * airmass / exp(-min(y0, 150.0) / haze_height);
	float fog = pow(clamp((dist - haze.x) / (haze.y - haze.x), 0.0, 1.0), haze.z) * haze.w * haze_share;
	vec3 behind_it = normalize(vec3(rd.x, max(rd.y, 0.0), rd.z));
	vec3 dome = zsSkyBase(behind_it);
	dome *= 0.98 / max(max(max(dome.r, dome.g), dome.b), 0.98);
	vec3 sky = scene_linear_for_display(dome);
	ALBEDO = mix(lit, sky, fog);

	float front = 1.0;
	vec4 sheet = texelFetch(cloud_shape, min(ivec2(FRAGCOORD.xy), textureSize(cloud_shape, 0) - 1), 0);
	float cloud_a = clamp(sheet.x, 0.0, 1.0);
	if (cloud_a > 0.003 && sheet.y / cloud_a < t) front = 1.0 - cloud_a;
	ALPHA = a * front;
}
