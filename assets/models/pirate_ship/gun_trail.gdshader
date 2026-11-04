shader_type spatial;
// The powder smoke a ball leaves on the air (ShipGuns `trail`): puffs let go
// along its line every few metres, each a MultiMesh instance at the spot,
// left there to swell, lift a little, drift on the wind and thin out, so the
// line it flew (a lob's arc) hangs in the air behind it. Discs turned to the
// eye, lit in the clouds' colours (gun_fx.gdshaderinc).
//   INSTANCE_CUSTOM  when it was let go (s, ShipGuns' clock `now`), seed,
//                    radius at first (m), 1 for a lob's
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;
#include "res://assets/models/pirate_ship/gun_fx.gdshaderinc"

uniform float now = 0.0;
// How long a puff lasts (s): a hull shot's, a lob's; how many times its first
// size it swells to; how fast it lifts (m/s); its opacity at the thickest;
// smoke's white against the lit cloud's value.
uniform vec2 life = vec2(2.2, 4.0);
uniform float swell = 2.6;
uniform float rise = 0.6;
uniform float opacity = 0.5;
uniform float white = 1.15;
uniform vec3 smoke = vec3(0.84, 0.84, 0.85);
// Faded out near the eye (m), so a line flown through doesn't wall the view.
const vec2 NEAR = vec2(3.0, 18.0);

varying vec2 v_q;
varying float v_alpha;
varying float v_seed;

void vertex() {
	v_q = UV * 2.0 - 1.0;
	v_seed = INSTANCE_CUSTOM.y;
	float t = now - INSTANCE_CUSTOM.x;
	float l = mix(life.x, life.y, INSTANCE_CUSTOM.w);
	float u = t / l;
	v_alpha = 0.0;
	if (t < 0.0 || u >= 1.0) {
		VERTEX = vec3(0.0, 0.0, 1e6);
	} else {
		vec3 at = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		at += gun_fx_wind() * 0.8 * t + vec3(0.0, rise * t, 0.0);
		float r = INSTANCE_CUSTOM.z * (1.0 + (swell - 1.0) * (1.0 - exp(-t * 1.6)));
		v_alpha = opacity * smoothstep(0.0, 0.06, t) * pow(1.0 - u, 1.5);
		VERTEX = (VIEW_MATRIX * vec4(at, 1.0)).xyz + vec3(v_q * r, 0.0);
	}
}

void fragment() {
	if (v_alpha <= 0.0) discard;
	float r = length(v_q);
	float a = atan(v_q.y, v_q.x);
	// Rounder than a burst's: strung close, they run together into one line.
	float reach = 0.95 + 0.05 * sin(a * 3.0 + v_seed * 6.3);
	float shape = pow(1.0 - smoothstep(0.0, reach, r), 1.6);
	float alpha = shape * v_alpha * smoothstep(NEAR.x, NEAR.y, length(VERTEX));
	if (alpha < 0.004) discard;
	vec3 rd = normalize(mat3(INV_VIEW_MATRIX) * VERTEX);
	float side;
	vec2 light = gun_fx_light(v_q, mat3(INV_VIEW_MATRIX), rd, side);
	ALBEDO = smoke * (light.x + light.y * (0.55 + 0.75 * side)) * white;
	ALPHA = alpha;
}
