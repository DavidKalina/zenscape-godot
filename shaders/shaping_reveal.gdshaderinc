#ifndef ZS_SHAPING_REVEAL
#define ZS_SHAPING_REVEAL
// Trees thin round a shaping tool at work (scripts/shaping_reveal.gd), so the
// ground under them shows. `zs_reveal_point` is the land under the pointer
// (global x, y, z) and the radius in metres; `zs_reveal_eye` the camera's
// position and the strength (0 off). Read in the fragment from the plant's
// root and its own local vertex, so it needs no varying of its own (the
// surface shader is at the 31-varying limit). Include after reference_season,
// whose noise it borrows.
global uniform vec4 zs_reveal_point;
global uniform vec4 zs_reveal_eye;

// The most of a tree that drops out at full strength: a faint ghost of the
// crown stays, so the forest still reads while you work under it.
const float ZS_REVEAL_MOST = 0.7;
// How tall a tree is taken to be, as a share of its mesh height (instances
// are scaled), and a metre over that the sight line may pass and still fade it.
const float ZS_REVEAL_TALL = 1.3;

// 0..1: how far this tree thins. Within the radius of the point, round its
// root; and along the sight line to the point, where the line passes lower
// than the tree's top (its root taken at the point's height).
float zs_reveal_amount(vec2 root, float tree_height) {
	if (zs_reveal_eye.w <= 0.0) return 0.0;
	vec3 at = zs_reveal_point.xyz;
	float radius = zs_reveal_point.w;
	float near = 1.0 - smoothstep(radius * 0.45, radius, distance(root, at.xz));
	vec2 eye = zs_reveal_eye.xz;
	vec2 run = at.xz - eye;
	float t = clamp(dot(root - eye, run) / max(dot(run, run), 1.0e-4), 0.0, 1.0);
	float off = distance(root, eye + run * t);
	float over = mix(zs_reveal_eye.y, at.y, t) - at.y;
	float top = tree_height * ZS_REVEAL_TALL;
	float sight = (1.0 - smoothstep(radius * 0.35, radius * 0.75, off)) * (1.0 - smoothstep(top, top + 1.0, over));
	return max(near, sight) * zs_reveal_eye.w;
}

// True where this fragment of a tree has dropped out. The clumps ride the
// tree's own vertices (`local`), so they hold still as the camera moves, and
// a fine screen grain softens their edges into a translucent look.
bool zs_revealed(vec3 local, vec2 root, float tree_height, vec2 frag) {
	float amount = zs_reveal_amount(root, tree_height) * ZS_REVEAL_MOST;
	if (amount <= 0.001) return false;
	float clump = zs_season_noise3(local * 2.2 + vec3(root.x, 0.0, root.y) * 0.53);
	float grain = fract(52.9829189 * fract(dot(frag, vec2(0.06711056, 0.00583715))));
	return mix(clump, grain, 0.35) < amount;
}
#endif
