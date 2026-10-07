#ifndef ZS_FOLIAGE_TREAD
#define ZS_FOLIAGE_TREAD
// Low foliage parting round the pilot on foot. `scripts/pilot_wake.gd`
// publishes his path as sixteen TREADS, `zs_tread_N = (x, z, radius, lean)`:
// slot 0 is where he is now, the rest where he has just been, newest first,
// and a radius of 0 ends the path. Each lean is already sprung on the CPU
// (PilotWake `spring`): held while he passes, then back past rest (negative)
// and settling, so the path behind him is a wake that closes up with a
// springy overshoot. A stem finds the nearest stretch of the path and leans
// out from it, a little along his way too, and whatever is right under him
// is pressed down (and pops up a little as it springs back). Called from the
// sway branch of `reference_surface.gdshader` and `dense_grass.gdshader`;
// mushrooms wobble on it (zs_tread_wobble). The trees' half below reads the
// old eight as round treads and has no walker feeding it now.
#include "res://shaders/reference_globals.gdshaderinc"

// How far a full-strength push leans a stem, as a fraction of the stem's own
// arm above its pivot (the same units the wind's lean uses), and how far down
// the centre of a tread presses whatever it stands on.
const float ZS_TREAD_REACH = 1.1;
const float ZS_TREAD_FLATTEN = 0.55;
// Metres of soft core round the path: a stem right on it is pressed rather
// than flung one way. Share of the lean along his way (stems dragged after
// him) and of the press that springs back up as a stretch.
const float ZS_TREAD_CORE = 0.12;
const float ZS_TREAD_DRAG = 0.35;
const float ZS_TREAD_POP = 0.5;

// Whether there is a wake to read at all (the pilot on foot, or his wake
// still settling).
bool zs_tread_live() {
	return zs_tread_0.z > 0.0;
}

// World-space xz direction*strength to shove the stem at `root` (length at
// most 1; negative leans, toward the path, are its spring-back), and the
// press (0..1 pressed down, below 0 popping up) at that root. Keep in step
// with PilotWake `push_at`.
vec2 zs_tread_push(vec2 root, out float press) {
	press = 0.0;
	if (!zs_tread_live() || root.x < zs_tread_box.x || root.y < zs_tread_box.y || root.x > zs_tread_box.z || root.y > zs_tread_box.w) return vec2(0.0);
	vec4 pts[16] = vec4[16](zs_tread_0, zs_tread_1, zs_tread_2, zs_tread_3, zs_tread_4, zs_tread_5, zs_tread_6, zs_tread_7,
		zs_tread_8, zs_tread_9, zs_tread_10, zs_tread_11, zs_tread_12, zs_tread_13, zs_tread_14, zs_tread_15);
	// Where he is now, alone, until a stretch of the path is nearer.
	vec2 off = root - pts[0].xy;
	float best = dot(off, off);
	float radius = pts[0].z;
	float lean = pts[0].w;
	vec2 way = vec2(0.0);
	for (int j = 0; j < 15; j++) {
		vec4 a = pts[j];
		vec4 b = pts[j + 1];
		if (b.z <= 0.0) break;
		// a is the newer end: his way along this stretch is from b to a.
		vec2 ab = a.xy - b.xy;
		float len2 = dot(ab, ab);
		if (len2 < 0.000001) continue;
		float s = clamp(dot(root - b.xy, ab) / len2, 0.0, 1.0);
		vec2 d = root - (b.xy + ab * s);
		float dist2 = dot(d, d);
		if (dist2 < best) {
			best = dist2;
			off = d;
			radius = mix(b.z, a.z, s);
			lean = mix(b.w, a.w, s);
			way = ab * inversesqrt(len2);
		}
	}
	float dist = sqrt(best);
	if (radius <= 0.0 || dist >= radius) return vec2(0.0);
	// 1 at the path, 0 at the rim, flat-topped: the middle of the wake is
	// parted evenly and its edge feathers out over the last two thirds.
	float w = 1.0 - smoothstep(0.3, 1.0, dist / radius);
	vec2 away = off / sqrt(best + ZS_TREAD_CORE * ZS_TREAD_CORE);
	vec2 push = (away + way * ZS_TREAD_DRAG) * (lean * w);
	float core = 1.0 - smoothstep(0.0, 0.55, dist / radius);
	press = (lean > 0.0 ? lean : lean * ZS_TREAD_POP) * core;
	press = clamp(press, -0.5, 1.0);
	float m = length(push);
	return m > 1.0 ? push / m : push;
}

// A stiff little thing (a mushroom cluster) brushed by him: it tips away
// about its foot by `amount` m at `height` (model units) per unit of lean,
// overshooting back and settling with the wake, and squashes a touch under
// him. The local-space offset for `vertex`.
vec3 zs_tread_wobble(vec3 vertex, mat4 model, float amount, float height) {
	float press;
	vec2 push = zs_tread_push(model[3].xz, press);
	if (dot(push, push) < 0.000001 && press == 0.0) return vec3(0.0);
	float k = clamp(vertex.y / max(height, 0.01), 0.0, 1.5);
	vec2 tip = push * amount * k;
	vec3 offset = inverse(mat3(model)) * vec3(tip.x, 0.0, tip.y);
	offset.y -= vertex.y * 0.18 * press;
	return offset;
}

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
