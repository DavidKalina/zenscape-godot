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

// The painted ground's turf colour, stirred (zs_react_tone; `turf` the
// share of open turf there).
vec3 zs_react_paint(vec3 grass, vec2 xz, vec2 to_eye, float turf) {
	if (!zs_react_live() || turf <= 0.0) return grass;
	vec3 r = zs_react_at(xz);
	if (dot(r, r) < 1.0e-6) return grass;
	return zs_react_tone(grass, zs_react_shade(r, to_eye) * turf);
}
#endif
