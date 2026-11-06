shader_type spatial;
// The steam trains' coal smoke and steam (scripts/endless/rail_smoke.gd): each
// puff a MultiMesh instance let go at a spot (the stack's mouth, a cylinder's
// steam point), its throw slowed by the air, lifting, drifting on the wind,
// swelling and fading, a disc turned to the eye, lit in the clouds' colours
// (gun_fx.gdshaderinc), so it follows the hour as the clouds do. Puffs stay
// where the air has them: the train runs on and the trail lies back along the
// line over its cars.
//   MODEL_MATRIX[0].xyz  the throw (m/s, the world's)
//   MODEL_MATRIX[1].xyz  radius at first and at the most (m), life (s)
//   MODEL_MATRIX[2].xyz  how pale at first (0 soot .. 1 smoke), opacity, lid
//                        (the most it rises over where it was let go, m)
//   MODEL_MATRIX[3].xyz  where it was let go (world)
//   INSTANCE_CUSTOM      when (s, RailSmoke's clock `now`), seed, role (0 the
//                        stack's, 1 steam, 2 the far plume), lift (m/s)
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform, fog_disabled;
#include "res://assets/models/pirate_ship/gun_fx.gdshaderinc"

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float now = 0.0;
// By role (stack, steam, far): the air's drag on the throw (1/s), the share of
// the wind it drifts on, and how fast it swells to its most (1/s).
uniform vec3 drag = vec3(1.6, 2.6, 0.9);
uniform vec3 wind_share = vec3(0.3, 0.5, 1.0);
uniform vec3 grow = vec3(0.7, 1.2, 0.12);
// Its grey: soot at the stack, paled to smoke by `pale` s; steam's white.
uniform vec3 soot : source_color = vec3(0.09, 0.085, 0.08);
uniform vec3 smoke : source_color = vec3(0.6, 0.6, 0.61);
uniform vec3 steam : source_color = vec3(0.97, 0.98, 1.0);
uniform vec3 far_smoke : source_color = vec3(0.86, 0.86, 0.87);
uniform float pale = 6.0;
// Where its edge starts to thin (a share of its radius), by role: a firm,
// chunky puff, the far plume's softer.
uniform vec3 core = vec3(0.55, 0.45, 0.35);
// The lit share against the clouds' light (gun_trail's `white`).
uniform float white = 1.1;
// A puff let go in a bore (its lid under BORE_LIT m) takes this share of the
// clouds' light: the sky doesn't reach it there.
uniform float bore_light = 0.3;
const float BORE_LIT = 1000.0;
// Faded near the eye (m, from x to y): smoke, steam; so a trail flown through
// doesn't wall the view.
uniform vec4 near = vec4(1.5, 8.0, 0.6, 3.0);
// The far plume: shown from far_in.x to far_in.y m off (the near smoke has it
// closer in), and swelling past far_grow.x m by one more of its size each
// far_grow.y m, so it still reads from across the land.
uniform vec2 far_in = vec2(300.0, 900.0);
uniform vec2 far_grow = vec2(1200.0, 1400.0);
// Its own haze, not the world's fog (which would wash the far plume out
// before it's found): toward the clouds' sky from haze.x to haze.y m off, at
// most haze.z of the way, on the world fog's curve (endless_flight.gd FOG_*).
uniform vec3 haze = vec3(900.0, 7000.0, 0.5);
// Faded where it meets what's behind it (m): no hard line cut across a puff
// by a roof, the ground or a bore's vault.
uniform float soft = 2.5;

varying vec2 v_q;
varying float v_alpha;
varying float v_seed;
varying float v_role;
varying vec3 v_grey;
varying float v_lit;

void vertex() {
	v_q = UV * 2.0 - 1.0;
	v_seed = INSTANCE_CUSTOM.y;
	v_role = INSTANCE_CUSTOM.z;
	v_grey = smoke;
	mat4 m = MODEL_MATRIX;
	v_lit = m[2].z < BORE_LIT ? bore_light : 1.0;
	float t = now - INSTANCE_CUSTOM.x;
	float u = t / max(m[1].z, 0.01);
	v_alpha = 0.0;
	if (t < 0.0 || u >= 1.0) {
		VERTEX = vec3(0.0, 0.0, 1e6);
	} else {
		int role = int(v_role + 0.5);
		float k = role == 0 ? drag.x : (role == 1 ? drag.y : drag.z);
		float w = role == 0 ? wind_share.x : (role == 1 ? wind_share.y : wind_share.z);
		float g = role == 0 ? grow.x : (role == 1 ? grow.y : grow.z);
		vec3 at = m[3].xyz + m[0].xyz * (1.0 - exp(-k * t)) / k;
		at += vec3(0.0, INSTANCE_CUSTOM.w * t, 0.0) + gun_fx_wind() * w * t;
		at.y = min(at.y, m[3].y + m[2].z);
		float r = mix(m[1].x, m[1].y, 1.0 - exp(-g * t));
		vec3 eye = (VIEW_MATRIX * vec4(at, 1.0)).xyz;
		float off = length(eye);
		float shown = 1.0;
		if (role == 2) {
			r *= 1.0 + max(off - far_grow.x, 0.0) / far_grow.y;
			shown = smoothstep(far_in.x, far_in.y, off);
		}
		// In fast (a puff is thrown, not faded in), out over its life.
		v_alpha = m[2].y * shown * smoothstep(0.0, 0.08, t) * (1.0 - u);
		if (role == 1) {
			v_grey = steam;
		} else if (role == 2) {
			v_grey = far_smoke;
		} else {
			v_grey = mix(soot, smoke, mix(m[2].x, 1.0, smoothstep(0.0, pale, t)));
		}
		VERTEX = eye + vec3(v_q * r, 0.0);
	}
}

void fragment() {
	if (v_alpha <= 0.0) discard;
	float r = length(v_q);
	float a = atan(v_q.y, v_q.x);
	// Chunky and a little lumpy, as a painted puff: lobes round the rim, each
	// puff its own by its seed, a firm edge rather than a haze.
	float reach = 0.84 + 0.09 * sin(a * 3.0 + v_seed * 6.3) + 0.06 * sin(a * 5.0 + v_seed * 11.7);
	float c = v_role < 0.5 ? core.x : (v_role < 1.5 ? core.y : core.z);
	float shape = 1.0 - smoothstep(reach * c, reach, r);
	vec2 fade = v_role > 0.5 && v_role < 1.5 ? near.zw : near.xy;
	float alpha = shape * v_alpha * smoothstep(fade.x, fade.y, length(VERTEX));
	float z = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 wp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z, 1.0);
	alpha *= clamp((-wp.z / wp.w + VERTEX.z) / soft, 0.0, 1.0);
	if (alpha < 0.004) discard;
	vec3 rd = normalize(mat3(INV_VIEW_MATRIX) * VERTEX);
	float side;
	vec2 light = gun_fx_light(v_q / reach, mat3(INV_VIEW_MATRIX), rd, side);
	ALBEDO = v_grey * (light.x + light.y * (0.55 + 0.75 * side)) * white * v_lit;
	float hz = haze.z * pow(clamp((length(VERTEX) - haze.x) / (haze.y - haze.x), 0.0, 1.0), 1.6);
	ALBEDO = mix(ALBEDO, zs_cloud_sky, hz);
	ALPHA = alpha;
}
