shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// The dust hanging in a light shaft (scripts/hall_shafts.gd). One instance a
// mote of a MultiMesh whose instance transform maps (u, v) of the roof
// opening onto the roof plane, INSTANCE_CUSTOM = (u, v, depth start, random).
// The vertex stage puts the mote in its beam (the same shear as the beam's
// shader, along the key light), sinks it slowly down the light, drifts it,
// and throws it about by the plane's wake: `wake_at` / `wake_way` are the
// plane's last few places (xyz, birth time) and ways (xyz, strength); a
// mote near one is pushed out of the path, swirled round it and dragged
// along it, all dying away with the point's age, so the dust billows round a
// pass and settles after. Camera-facing, with a soft round falloff.
#include "res://shaders/reference_globals.gdshaderinc"

uniform float roof_y = 11.4;
uniform float floor_y = 0.0;
uniform float max_len = 46.0;
uniform float gain = 1.0;
uniform float now = 0.0;
uniform vec4 wake_at[8];
uniform vec4 wake_way[8];

varying float bright;
varying vec3 tint;

float light_strength() {
	vec3 k = zs_key_irradiance;
	float lum = (k.x + k.y + k.z) / 3.0;
	return clamp(lum / 2.4, 0.0, 1.0) * clamp(zs_celestial_clear, 0.0, 1.0);
}

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	vec3 k = zs_key_direction;
	float kl = length(k);
	vec3 way = kl > 0.5 ? -k / kl : vec3(0.0, -1.0, 0.0);
	float elev = -way.y;
	float len = min((roof_y - floor_y) / max(elev, 0.12), max_len);
	float live = kl > 0.5 ? smoothstep(0.12, 0.4, elev) : 0.0;
	// Sinks slowly, looping down its beam.
	float t = fract(c.z + TIME * (0.06 + 0.06 * c.w) / max(len, 4.0));
	vec3 base = (MODEL_MATRIX * vec4(c.x, 0.0, c.y, 1.0)).xyz;
	vec3 pos = base + way * len * t;
	pos += vec3(sin(TIME * 0.31 + c.w * 40.0), sin(TIME * 0.23 + c.x * 30.0) * 0.5, cos(TIME * 0.27 + c.y * 50.0)) * 0.55;
	// The plane's wake.
	vec3 moved = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		vec4 wa = wake_at[i];
		vec4 ww = wake_way[i];
		if (ww.w > 0.0) {
			float age = max(now - wa.w, 0.0);
			vec3 r = pos - wa.xyz;
			float along = dot(r, ww.xyz);
			vec3 rad = r - ww.xyz * along;
			float rl = length(rad) + 0.001;
			float infl = exp(-rl * rl / 36.0) * exp(-along * along / 100.0);
			float env = exp(-age * 0.75) * ww.w;
			vec3 rn = rad / rl;
			float ph = age * 3.2 + c.w * 6.2832;
			moved += infl * env * (rn * 3.4 * (1.0 - exp(-age * 5.0)) + cross(ww.xyz, rn) * sin(ph) * 3.0 + ww.xyz * 4.0 * (1.0 - exp(-age * 4.0)));
		}
	}
	pos += moved;
	float stirred = clamp(length(moved) * 0.35, 0.0, 1.0);
	vec3 eye = CAMERA_POSITION_WORLD;
	float dist = length(pos - eye);
	float real = 0.09 + 0.16 * c.x * c.y + 0.05 * c.w;
	float size = max(real, dist * 0.0032);
	// Looking into the sun the motes flare.
	vec3 look = (pos - eye) / max(dist, 0.001);
	float into = max(dot(look, normalize(zs_key_direction + vec3(0.0, 1e-4, 0.0))), 0.0);
	float twinkle = 0.55 + 0.45 * sin(TIME * (1.3 + 2.0 * c.w) + c.z * 31.0);
	float along_fade = smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.5, 0.98, t));
	bright = gain * light_strength() * live * along_fade * twinkle * (0.55 + 1.7 * pow(into, 3.0)) * (1.0 + 1.2 * stirred)
		* clamp(real / size, 0.3, 1.0) * smoothstep(0.6, 3.5, dist) * (1.0 - smoothstep(55.0, 90.0, dist));
	vec3 kk = zs_key_irradiance;
	float lum = max((kk.x + kk.y + kk.z) / 3.0, 1e-3);
	tint = mix(kk / lum, vec3(1.0, 0.88, 0.66), 0.4);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 world = pos + (right * VERTEX.x + up * VERTEX.y) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float soft = exp(-d * d * 3.5) * (1.0 - smoothstep(0.8, 1.0, d));
	ALBEDO = tint * bright * soft * 1.6;
}
