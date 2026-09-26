#ifndef ZS_FOLIAGE_TREAD
#define ZS_FOLIAGE_TREAD
// Low foliage parting round a walker. `scripts/foliage_tread.gd` publishes
// eight TREADS, `zs_tread_N = (x, z, radius, strength)`: slot 0 is where he
// stands, the rest are where he has just been, fading. A stem inside a tread
// is pushed radially away from its centre and lies over, so from above he
// walks in a hole with a trough behind him. Called from the sway branch of
// `reference_surface.gdshader`; nothing here for trees.
#include "res://shaders/reference_globals.gdshaderinc"

// How far a full-strength push leans a stem, as a fraction of the stem's own
// arm above its pivot (the same units the wind's lean uses), and how far down
// the centre of a tread presses whatever it stands on.
const float ZS_TREAD_REACH = 1.1;
const float ZS_TREAD_FLATTEN = 0.55;

// TREES. The same field, read wider: a crown gives way to a walker from
// further off than a flower does. Every tread's radius is scaled by this, the
// lean is in true metres (a tall tree and a short one within reach of him
// both move their crowns about this far), and the bend rises up the tree so
// the root stays planted and the tip moves most. Trunk and crown call this
// with the same tree height, so a tree stays one object. Tuned down on
// 2026-09-11 from 2.5 / 1.8: the user wants a subtle give, just enough to say
// the trees do not block him, not trees hauled aside.
const float ZS_TREE_TREAD_RADIUS = 2.0;
const float ZS_TREE_TREAD_REACH = 0.7;
const float ZS_TREE_TREAD_POWER = 1.6;

void zs_tread_one(vec4 tread, vec2 root, float radius_scale, inout vec2 push, inout float press) {
	if (tread.w <= 0.0) return;
	vec2 away = root - tread.xy;
	float d = length(away);
	float radius = tread.z * radius_scale;
	if (d >= radius) return;
	// 1 at the centre, 0 at the rim, flat-topped: the middle of a footprint is
	// pressed evenly and the edge feathers out over the last third.
	float w = (1.0 - smoothstep(0.35, 1.0, d / radius)) * tread.w;
	push += (d > 0.03 ? away / d : vec2(0.0)) * w;
	press = max(press, w);
}

// World-space xz direction*strength to shove the stem, length at most 1, and
// the deepest press (0..1) any tread puts on this root, with every tread's
// radius scaled by `radius_scale`.
vec2 zs_tread_push_scaled(vec2 root, float radius_scale, out float press) {
	vec2 push = vec2(0.0);
	press = 0.0;
	zs_tread_one(zs_tread_0, root, radius_scale, push, press);
	zs_tread_one(zs_tread_1, root, radius_scale, push, press);
	zs_tread_one(zs_tread_2, root, radius_scale, push, press);
	zs_tread_one(zs_tread_3, root, radius_scale, push, press);
	zs_tread_one(zs_tread_4, root, radius_scale, push, press);
	zs_tread_one(zs_tread_5, root, radius_scale, push, press);
	zs_tread_one(zs_tread_6, root, radius_scale, push, press);
	zs_tread_one(zs_tread_7, root, radius_scale, push, press);
	float m = length(push);
	return m > 1.0 ? push / m : push;
}

vec2 zs_tread_push(vec2 root, out float press) {
	return zs_tread_push_scaled(root, 1.0, press);
}

void zs_tree_tread_one(vec4 tread, float envelope, vec2 root, inout vec2 push) {
	vec2 away = root - tread.xy;
	float radius = tread.z * ZS_TREE_TREAD_RADIUS;
	if (tread.w <= 0.0 || envelope <= 0.0 || radius <= 0.0) return;
	float d = length(away);
	float weight = (1.0 - smoothstep(0.35, 1.0, d / radius)) * tread.w * envelope;
	// A soft core avoids a direction snap when the walker crosses the root.
	push += away / sqrt(dot(away, away) + 0.16) * weight;
}

vec2 zs_tree_tread_push(vec2 root) {
	vec2 push = vec2(0.0);
	zs_tree_tread_one(zs_tread_0, zs_tree_tread_weights_0.x, root, push);
	zs_tree_tread_one(zs_tread_1, zs_tree_tread_weights_0.y, root, push);
	zs_tree_tread_one(zs_tread_2, zs_tree_tread_weights_0.z, root, push);
	zs_tree_tread_one(zs_tread_3, zs_tree_tread_weights_0.w, root, push);
	zs_tree_tread_one(zs_tread_4, zs_tree_tread_weights_1.x, root, push);
	zs_tree_tread_one(zs_tread_5, zs_tree_tread_weights_1.y, root, push);
	zs_tree_tread_one(zs_tread_6, zs_tree_tread_weights_1.z, root, push);
	zs_tree_tread_one(zs_tread_7, zs_tree_tread_weights_1.w, root, push);
	return push / max(1.0, length(push));
}

// The local-space offset that leans a tree part away from the walker. `vertex`
// is the part's local vertex, `tree_height` the whole tree's height in the
// same units (the trunk and the crown of one tree share them). The lean is
// world metres turned local like the wind's; the droop keeps the crown from
// stretching as it leans, as `zs_conifer_offset` does.
vec3 zs_tree_tread(vec3 vertex, mat4 model, float tree_height) {
	vec2 push = zs_tree_tread_push(model[3].xz);
	float height = max(vertex.y, 0.0);
	float bend = pow(clamp(height / max(tree_height, 0.1), 0.0, 1.0), ZS_TREE_TREAD_POWER);
	vec2 lean = push * ZS_TREE_TREAD_REACH * bend;
	float scale = max(length(model[1].xyz), 0.001);
	float droop = dot(lean, lean) / max(2.0 * height * scale, 0.5);
	return inverse(mat3(model)) * vec3(lean.x, -droop, lean.y);
}
#endif
