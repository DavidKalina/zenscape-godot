shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
// The ruins' growth (scripts/ruin_growth.gd, docs/scenic/ruin-overgrowth.md):
// the ivy, vine curtains, tendrils, leaf mats, tufts and moss cushions the
// ruin kit grows on its stone, split from the stone's surface so they live in
// the same air as the grass. Faceted shapes, soft light: each piece keeps its
// cut silhouette but lights as a soft mass (its strand's facing, not its
// facets), dark at the root and lifted toward the tip, the tips glowing when
// backlit (grass_look's translucency).
//
// Every vertex carries where it hangs from (scripts/ruin_growth.gd `attrs`):
//   UV       x: metres from its anchor (below it for a hanging strand, above
//               it, negative, for an upright tuft; 0 pinned), y: the strand's
//               length (m), 0 for what does not sway
//   UV2      x: its clump's phase (0..1), y: how much it flutters (0..1)
//   CUSTOM0  xy: the face its strand lies on (x, z in the mesh's frame; 0
//               for a strand hanging free), z: how free it hangs (0 pressed
//               to stone, 1 in the air), w: its share of the root-to-tip
//               colour (0 root, 1 tip)
// A strand bends from its anchor: the root stays pinned, the tip swings most
// ((reach / length)^1.5), lags the air at the anchor a beat per metre and
// swings at a hanging rope's pace; pressed strands slide along their face and
// peel off it, never into it. Leaf clumps flutter on top. Moss never moves.
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/grass_look.gdshaderinc"
#include "res://shaders/foliage_tread.gdshaderinc"

// 0 holds every piece still (the gallery's compare), 1 the wind as is.
uniform float motion = 1.0;
// How far a strand's tip blows out per unit of the breeze's lean, as a share
// of its length; how far it swings round that; its calm sway (m at the tip
// of a 1 m strand, also the floor in still air).
uniform float sway_gain = 1.25;
uniform float swing_share = 0.55;
uniform float calm_sway = 0.06;
// The leaf clumps' flutter (m at full gust).
uniform float flutter_gain = 0.045;
// How much a pressed strand gives, against a free one.
uniform float pressed_give = 0.45;
// A plane or the pilot brushing past (scripts/ruin_growth_push.gd): up to
// four pushers, each (x, y, z, radius) and its push (x, y, z, strength), the
// strength already sprung on the CPU (held, then back past rest and
// settling). Strength 0 is none.
uniform vec4 pusher_at[4];
uniform vec4 pusher_way[4];

// Colour: root shade and tip lift (multipliers), and the tips' glow.
uniform vec3 root_shade = vec3(0.62, 0.68, 0.6);
uniform vec3 tip_lift = vec3(1.24, 1.24, 0.9);
uniform float tip_translucency = 0.6;
uniform float fill = 1.25;
uniform float rim = 0.12;
// How soft the light: 0 each facet its own, 1 the strand's mass only.
uniform float soft = 0.6;
// Under a roof (vertex alpha, as the stone's: 1 open air, 0 deep under).
uniform float shelter_fill = 4.5;
uniform vec3 shelter_tint : source_color = vec3(1.0, 0.82, 0.6);

varying vec3 mass_normal;
varying float along;
varying float sheen;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float hang = UV.x;
	float span = UV.y;
	float reach = abs(hang);
	vec2 out_face = (MODEL_MATRIX * vec4(CUSTOM0.x, 0.0, CUSTOM0.y, 0.0)).xz;
	float free_share = CUSTOM0.z;
	along = CUSTOM0.w;
	sheen = 0.0;
	vec3 moved = vec3(0.0);
	if (span > 0.01 && motion > 0.0) {
		float k = clamp(reach / span, 0.0, 1.0);
		float bend = pow(k, 1.5);
		// A strand hangs nearly straight down, so its vertices share its
		// anchor's x, z: the whole strand reads one patch of air.
		vec2 root = world.xz;
		float phase = dot(root, vec2(0.43, 0.71));
		float bow;
		float lean = zs_breeze_lean_at(root, ZS_BREEZE_LAG * reach, 0.0, bow);
		float gust = clamp(lean / 0.6, 0.0, 1.0);
		float pace = zs_breeze_pace(span) * 0.85;
		float t = zs_motion_time;
		float swing = sin(t * pace + phase - k * 1.4) * 0.7 + sin(t * pace * 1.63 + phase * 1.7 - k * 2.1) * 0.3;
		float wander = sin(t * pace * 0.71 + phase * 2.3 - k * 0.9) * 0.6 + sin(t * pace * 1.31 + phase * 0.7) * 0.4;
		vec2 dir = zs_wind_direction;
		vec2 side = vec2(-dir.y, dir.x);
		vec2 d = (dir * lean * (1.0 + swing_share * swing) + side * wander * (0.18 + 0.35 * lean)) * sway_gain * span * bend;
		d += (dir * swing + side * wander) * calm_sway * zs_breeze_air() * bend * span;
		// The wind tool's air and the local gusts, as the grass takes them.
		float blow_shiver;
		vec2 blow = zs_blow_at(root, phase, blow_shiver);
		d += blow * span * bend * 0.9;
		vec3 air = zs_local_wind(world);
		float air_speed = length(air);
		if (air_speed > 0.001) d += air.xz / air_speed * (air_speed / (air_speed + 10.0)) * span * bend;
		// The pilot's wake on foot (foliage_tread).
		if (zs_tread_live()) {
			float press;
			d += zs_tread_push(root, press) * min(span, 1.5) * bend * 0.8;
		}
		// A plane or the pilot brushing past (ruin_growth_push.gd), in 3D:
		// shoved along its way and out from its path.
		for (int i = 0; i < 4; i++) {
			vec4 p = pusher_at[i];
			vec4 w = pusher_way[i];
			if (p.w <= 0.0 || w.w == 0.0) continue;
			vec3 rel = world - p.xyz;
			float r = length(rel);
			if (r >= p.w) continue;
			float fall = 1.0 - smoothstep(0.25 * p.w, p.w, r);
			vec2 away = rel.xz / max(length(rel.xz), 0.3);
			d += (w.xz + away * 0.6) * w.w * fall * min(span, 2.5) * bend * 0.7;
			gust = max(gust, abs(w.w) * fall);
		}
		// Never further than the strand's own reach (it swings, not stretches).
		float d_len = length(d);
		float most = reach * 0.95 + 0.02;
		if (d_len > most) d *= most / d_len;
		// Pressed to stone: slides along its face and peels off it, never in.
		float give = mix(pressed_give, 1.0, free_share);
		d *= give;
		float olen = length(out_face);
		if (olen > 0.1 && free_share < 0.99) {
			vec2 o = out_face / olen;
			float into = dot(d, o);
			d -= o * min(into, 0.0);
			d += o * length(d) * 0.35 * (1.0 - free_share);
		}
		// Keeping its length: a hanging tip rises as it swings, a tuft's dips.
		float rise = min(dot(d, d) / (2.0 * max(reach, 0.05)), reach * 0.7);
		moved = vec3(d.x, hang >= 0.0 ? rise : -rise, d.y);
		// The leaf clumps flutter on top, each its own way, harder in a gust.
		float flutter = UV2.y * zs_breeze_air() * (0.35 + 0.65 * max(gust, blow_shiver)) * flutter_gain * (0.4 + 0.6 * bend);
		float clump = UV2.x * TAU;
		vec3 shake = vec3(sin(t * 11.0 + clump * 3.0), sin(t * 8.3 + clump * 5.0) * 0.6, cos(t * 12.7 + clump * 2.0));
		vec3 twist = vec3(sin(t * 15.0 + dot(VERTEX, vec3(19.0, 23.0, 17.0))), 0.0, cos(t * 13.0 + dot(VERTEX, vec3(13.0, 29.0, 11.0)))) * 0.35;
		moved += (shake + twist) * flutter;
		sheen = gust * bend;
	} else if (UV2.y > 0.0 && motion > 0.0) {
		// A leaf mat on a top: only its flutter.
		float clump = UV2.x * TAU;
		float t = zs_motion_time;
		float f = UV2.y * zs_breeze_air() * flutter_gain * 0.5;
		moved = vec3(sin(t * 9.0 + clump * 3.0), sin(t * 7.1 + clump * 5.0) * 0.5, cos(t * 10.3 + clump * 2.0)) * f;
	}
	VERTEX += inverse(mat3(MODEL_MATRIX)) * moved * motion;
	// The soft mass: the face its strand lies on (or its facing, for a free
	// curtain), tipped a little up; moss and mats look up.
	vec3 facing = length(CUSTOM0.xy) > 0.1 ? normalize(vec3(CUSTOM0.x, 0.45, CUSTOM0.y)) : vec3(0.0, 1.0, 0.0);
	vec3 facet = normalize(NORMAL);
	if (dot(facet, facing) < 0.0 && span > 0.01) facet = -facet;
	vec3 local_normal = normalize(mix(facet, facing, soft));
	mass_normal = normalize((MODEL_MATRIX * vec4(local_normal, 0.0)).xyz);
}

void fragment() {
	vec3 base = COLOR.rgb * mix(root_shade, tip_lift, pow(clamp(along, 0.0, 1.0), 0.8));
	// Bowed by a gust, its leaves turn their pale backs.
	base *= 1.0 + 0.22 * sheen;
	ALBEDO = base;
	ROUGHNESS = 0.9;
	NORMAL = normalize((VIEW_MATRIX * vec4(mass_normal, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, mass_normal.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	EMISSION = base * hemi * fill + base * zs_hemi_sky * zs_hemi_energy * edge * rim;
	float shelter = 1.0 - COLOR.a;
	EMISSION += base * mix(zs_hemi_sky, shelter_tint, 0.65) * zs_hemi_energy / PI * shelter_fill * 0.6 * shelter;
}

void light() {
	// Wrapped a little, as thin leaves pass light round their edges.
	float nl = clamp((dot(NORMAL, LIGHT) + 0.25) / 1.25, 0.0, 1.0);
	vec3 energy = LIGHT_COLOR * ATTENUATION;
	DIFFUSE_LIGHT += energy * nl / PI;
	DIFFUSE_LIGHT += energy * zs_grass_translucency(LIGHT, VIEW, ALBEDO, max(along, 0.35), tip_translucency);
}
