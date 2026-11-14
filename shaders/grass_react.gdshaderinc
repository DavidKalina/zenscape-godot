#ifndef ZS_GRASS_REACT
#define ZS_GRASS_REACT
// The grass reacting (scripts/endless/grass_react.gd, docs/design/endless-
// flight/grass-react-handoff.md): the prop's wash, the walker and the
// gusts landing push the grass through one world-space map round the eye,
// zs_react_map, redrawn every frame from their stamps (each stamp's spring,
// its push, overshoot back and settling, is worked out from its age in
// shaders/grass_react_stamp.gdshader). Per texel: rg the push (world x, z;
// the lean's share, about 1 a full lean, negative back past rest), b the
// press (1 laid flat, below 0 popping up). zs_react_rect: the map's min x,
// min z, its size in m, and the bend's strength (0: off, nothing read).
// The isles never set it, so for them all of this is skipped.
global uniform sampler2D zs_react_map : filter_linear, repeat_disable;
global uniform vec4 zs_react_rect;

// How far a full push leans a blade (a share of its arm above the pivot,
// as the tread's ZS_TREAD_REACH), how far the press lays it down, and the
// most a sum of stamps leans it.
const float ZS_REACT_REACH = 1.2;
const float ZS_REACT_FLATTEN = 0.75;
const float ZS_REACT_MAX = 1.25;

bool zs_react_live() {
	return zs_react_rect.w > 0.0;
}

// The push (xy) and press (z) at a world xz point, faded out at the map's rim.
vec3 zs_react_at(vec2 xz) {
	if (!zs_react_live()) return vec3(0.0);
	vec2 uv = (xz - zs_react_rect.xy) / zs_react_rect.z;
	if (uv.x <= 0.0 || uv.y <= 0.0 || uv.x >= 1.0 || uv.y >= 1.0) return vec3(0.0);
	vec2 rim = min(uv, 1.0 - uv);
	float keep = smoothstep(0.0, 0.06, min(rim.x, rim.y));
	vec3 r = textureLod(zs_react_map, uv, 0.0).rgb * (keep * zs_react_rect.w);
	float m = length(r.xy);
	if (m > ZS_REACT_MAX) r.xy *= ZS_REACT_MAX / m;
	r.z = clamp(r.z, -0.5, 1.0);
	return r;
}

// How a stirred patch reads (-1..1): blades laid over away from the eye
// show their paler, sunlit flank (positive), blades leant toward it their
// shaded tips (negative); pressed flat they pale either way. `to_eye` the
// way from the patch to the eye (xz). Read as a sheen by the far tufts and
// the ground's paint, and its pale side as grass_bow by the near tufts.
float zs_react_shade(vec3 r, vec2 to_eye) {
	vec2 e = to_eye / max(length(to_eye), 0.001);
	float away = -dot(r.xy, e);
	return clamp(length(r.xy) * 0.3 + away * 0.8 + max(r.z, 0.0) * 0.5, -0.7, 1.0);
}

// The colour a stirred patch takes for `shade` (zs_react_shade).
vec3 zs_react_tone(vec3 c, float shade) {
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	vec3 pale = mix(c, vec3(l) * vec3(1.0, 1.12, 0.78), 0.3) * 1.5;
	return shade >= 0.0 ? mix(c, pale, shade * 0.7) : mix(c, c * 0.7, -shade * 0.7);
}

// The local-space offset for a blade vertex: `root` its plant's world xz,
// `arm` its height over the pivot in world m, `bend` its bend share (0 at
// the root, 1 at the tip), `model` its MODEL_MATRIX, `scale` the plant's
// scale. The lean keeps the blade's length (it drops as it leans), the press
// lays it down. `sheen` takes zs_react_shade there (`to_eye` as for it).
vec3 zs_react_offset(vec2 root, float arm, float bend, mat4 model, float scale, vec2 to_eye, inout float sheen) {
	vec3 r = zs_react_at(root);
	if (dot(r, r) < 1.0e-7) return vec3(0.0);
	sheen = zs_react_shade(r, to_eye);
	vec2 shove = r.xy * (arm * ZS_REACT_REACH * bend);
	float lean_sq = min(dot(shove, shove), arm * arm * 0.96);
	float drop = (arm - sqrt(arm * arm - lean_sq)) + arm * bend * r.z * ZS_REACT_FLATTEN;
	vec3 offset = inverse(mat3(model)) * vec3(shove.x, 0.0, shove.y);
	offset.y -= drop / max(scale, 0.001);
	return offset;
}

// The near blades lying over as one combed mat (zs_react_lay 1; 0 or
// --grass-part=old: zs_react_offset's shove and drop, which on two-segment
// blades folded at the joint like a paper strip and dug the tips into the
// ground). The blade bends as a curve whose angle from upright runs
// theta * (1 - (1 - t)^k) up it (t the share of its length): a gentle lean is
// an even arc (k 1), laid down the bend gathers at the root (k
// ZS_REACT_ARC_ROOT) and the rest lies near flat, its length kept, the tip
// off the ground.
global uniform float zs_react_lay;
// The lean's share of the lay (a full push of 1 lays a blade this far), the
// press's, the tip's most angle from upright (rad), and how low a laid
// blade's bend gathers.
const float ZS_REACT_ARC_LEAN = 0.8;
const float ZS_REACT_ARC_PRESS = 0.5;
const float ZS_REACT_ARC_MOST = 1.42;
const float ZS_REACT_ARC_ROOT = 2.6;
// A laid blade's soft-mass normal (reference_surface): the share of the
// tuft's dome it loses, and how far it tips the way the blades lie.
const float zs_react_lay_dome = 0.7;
const float zs_react_lay_tilt = 0.0;
// A laid blade's root-to-tip share starts this far up (the root's dark).
const float zs_react_lay_root = 0.3;

bool zs_react_arcs() {
	return zs_react_lay > 0.5;
}

// zs_react_offset for a near blade: `blade` its length over the pivot (world
// m). `lay` comes back 0 standing to 1 laid down and `way` the world xz way
// it lies, for the soft-mass normal.
vec3 zs_react_arc(vec2 root, float arm, float blade, mat4 model, float scale, vec2 to_eye, inout float sheen, inout float lay, inout vec2 way) {
	vec3 r = zs_react_at(root);
	if (dot(r, r) < 1.0e-7) return vec3(0.0);
	sheen = zs_react_shade(r, to_eye);
	float m = length(r.xy);
	if (m < 1.0e-4 && r.z <= 0.0) return vec3(0.0);
	way = m > 1.0e-4 ? r.xy / m : vec2(0.0);
	lay = clamp(m * ZS_REACT_ARC_LEAN + max(r.z, 0.0) * ZS_REACT_ARC_PRESS, 0.0, 1.0);
	float theta = lay * ZS_REACT_ARC_MOST;
	float k = mix(1.0, ZS_REACT_ARC_ROOT, lay);
	float len = max(blade, 0.05);
	float s = arm / len;
	float h = min(s, 1.0) * 0.25;
	vec2 p = vec2(0.0);
	for (int i = 0; i < 4; i++) {
		float phi = theta * (1.0 - pow(1.0 - (float(i) + 0.5) * h, k));
		p += vec2(sin(phi), cos(phi)) * h;
	}
	p += vec2(sin(theta), cos(theta)) * max(s - 1.0, 0.0);
	p *= len;
	vec3 offset = inverse(mat3(model)) * vec3(way.x * p.x, 0.0, way.y * p.x);
	offset.y += (p.y - arm) / max(scale, 0.001);
	return offset;
}

// The painted ground's turf colour, stirred (zs_react_tone; `turf` the
// share of open turf there).
vec3 zs_react_paint(vec3 grass, vec2 xz, vec2 to_eye, float turf) {
	if (!zs_react_live() || turf <= 0.0) return grass;
	vec3 r = zs_react_at(xz);
	if (dot(r, r) < 1.0e-6) return grass;
	return zs_react_tone(grass, zs_react_shade(r, to_eye) * turf);
}
#endif
