shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// The disturbed pool at the foot of the waterfall (study:
// studies/waterfall_study.tscn): a flat plane just above the pool's surface.
// The foam spreads from the impact: solid and churning under and against the
// churn mound, then breaking into rafts and thin streaks carried outward,
// thinning with distance, with ripples pushed out over the open water.
//
// The pattern lives in the flow's own frame: `a` runs along the mound's edge
// (a rounded outline hugging the fall's foot), `d` straight out from it. The
// foam is carried out along `d` and slows as it goes; around the corners the
// streaks fan out. Gradient noise, its octaves turned against each other and
// its domain warped and churned in time, so nothing lines up with the axes or
// repeats. `v_world` x is across the fall, z out from the wall.
uniform float half_width = 13.0;
// The fall's front at the foot (m out from the wall) and how far its churn
// mound reaches past it: the foam's solid edge is there.
uniform float front_z = 5.4;
uniform float mound_reach = 3.0;
// How much wider each side of the fall is at the foot than at the lip (m).
uniform float spread = 2.6;
// How far the foam reaches out past the mound (m).
uniform float reach : hint_range(1.0, 16.0) = 11.0;
// Metres per second the foam drifts out next to the mound (it slows further out).
uniform float drift : hint_range(0.0, 6.0) = 1.8;
// How far out the solid foam against the mound runs (m), before it breaks up.
uniform float solid : hint_range(0.0, 4.0) = 1.8;
// How much of the open water the rafts cover near the mound (0..1).
uniform float coverage : hint_range(0.0, 1.0) = 0.6;
// Ripples carried out over the open water (0 none).
uniform float ripples : hint_range(0.0, 1.0) = 0.5;
uniform vec3 foam_color : source_color = vec3(0.95, 0.98, 1.0);
// In the flight (scripts/endless/world/wilderness/waterfall.gd): the plane is
// a child of the fall and its pattern is in the fall's frame (`in_fall`: the
// mesh's own points plus `fall_offset`, its place in the fall), and it takes
// the world's light (`world_light`: the key light and sky fill, as the fall's
// shaders/waterfall_volume.gdshader does).
uniform bool in_fall = false;
uniform vec3 fall_offset = vec3(0.0);
uniform float world_light = 0.0;
uniform float world_gain = 1.0;
global uniform vec3 zs_key_direction;
global uniform vec3 zs_key_irradiance;
global uniform vec3 zs_hemi_sky;
global uniform float zs_hemi_energy;
varying vec3 v_world;

void vertex() { v_world = in_fall ? VERTEX + fall_offset : (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

float h21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

// Gradient noise, about -0.7..0.7.
float gn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float ga = h21(i) * 6.2831853;
	float gb = h21(i + vec2(1.0, 0.0)) * 6.2831853;
	float gc = h21(i + vec2(0.0, 1.0)) * 6.2831853;
	float gd = h21(i + vec2(1.0, 1.0)) * 6.2831853;
	float a = dot(vec2(cos(ga), sin(ga)), f);
	float b = dot(vec2(cos(gb), sin(gb)), f - vec2(1.0, 0.0));
	float c = dot(vec2(cos(gc), sin(gc)), f - vec2(0.0, 1.0));
	float d = dot(vec2(cos(gd), sin(gd)), f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Octaves turned against each other (no axis shows through).
const mat2 ROT = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
float fbm(vec2 p) {
	float s = gn(p) * 0.55;
	p = ROT * p * 2.03 + 3.1;
	s += gn(p) * 0.28;
	p = ROT * p * 2.07 + 1.7;
	s += gn(p) * 0.14;
	return s;
}

// The flow frame: a along the mound's edge, d out from it (negative under it).
void frame(vec2 p, out float a, out float d) {
	float hw = half_width + spread;
	float ze = front_z + mound_reach;
	float R = 3.0;
	float x = abs(p.x);
	if (x <= hw) {
		d = p.y - ze;
		a = x;
	} else if (p.y >= ze - R) {
		vec2 v = vec2(x - hw, p.y - (ze - R));
		d = length(v) - R;
		a = hw + atan(v.x, v.y) * R;
	} else {
		d = x - hw - R;
		a = hw + 1.5707963 * R + (ze - R - p.y);
	}
	a *= sign(p.x);
}

float aa(float edge, float v, float w) {
	return smoothstep(edge - w, edge + w, v);
}

void fragment() {
	float a, d;
	frame(v_world.xz, a, d);
	float t = TIME;
	// Carried out, slowing with distance: the pattern moves in s, which
	// grows ever slower than d.
	float L = 7.0;
	float s = L * log(1.0 + max(d, 0.0) / L) + min(d, 0.0);
	float sa = s - t * drift;
	// The water churns: the frame is warped, and the warp itself changes.
	vec2 fp = vec2(a * 0.5, sa * 0.62);
	vec2 w = vec2(gn(fp * 0.9 + vec2(t * 0.11, 3.7)), gn(fp * 0.9 + vec2(8.3, -t * 0.13)));
	vec2 wp = fp + w * 1.1;
	float far = smoothstep(0.0, reach, d);

	// Rafts: one field whose bar rises with distance, so the foam is whole
	// by the mound, then holed, then breaks into rafts that thin out; its
	// ragged edges come from the finer octaves.
	float rn = fbm(wp * 1.9 + vec2(0.0, t * 0.05));
	float bias = mix(-0.3, 0.3, pow(clamp((d + 0.4) / reach, 0.0, 1.0), 0.75)) - 0.2 * (coverage - 0.5);
	float rw = max(fwidth(rn) * 0.8, 0.012);
	float rafts = aa(bias, rn, rw) * (1.0 - smoothstep(reach * 0.5, reach * 1.3, d + 2.0 * gn(wp * 0.7 + 4.0)));

	// Streaks: the zero lines of a noise stretched along the flow, so thin
	// curved lines pulled out from the mound; broken into lengths.
	vec2 sp = vec2(a * 0.8 + w.x * 1.4, sa * 0.3 + w.y * 0.4);
	float sn = gn(sp) + 0.35 * gn(sp * vec2(2.3, 1.7) + 5.0);
	float sw = max(fwidth(sn) * 0.9, 0.012);
	float line = 1.0 - aa(0.035, abs(sn), sw);
	float seg = aa(0.12, gn(vec2(a * 0.45 + 7.0, sa * 0.7) + w * 0.7), 0.06);
	float streaks = line * seg * (1.0 - smoothstep(reach * 0.25, reach * 1.1, d));

	// Against the mound: solid, churning, its outer edge ragged and moving.
	float edge = solid * (0.55 + 0.9 * (fbm(vec2(a * 0.5, t * 0.35)) + 0.5));
	float en = fbm(wp * 2.2 - vec2(0.0, t * 0.4)) * 0.6;
	float near = 1.0 - aa(edge, d + en, 0.06);
	// Small holes in the solid foam, more toward its edge.
	float hn = fbm(vec2(a, s) * 2.6 + w * 1.5 + vec2(t * 0.3, -t * 0.9));
	float holes = aa(mix(-0.45, -0.05, smoothstep(-1.0, edge, d)), hn, 0.03);
	near *= mix(1.0, holes, smoothstep(-1.5, 0.0, d));

	float foam = max(near, max(rafts * 0.97, streaks * 0.85));
	// Ripples pushed out over the open water: short bright crests in
	// broken arcs, warped so no two run parallel for long.
	float rp = sin((sa + w.x * 1.6 + gn(fp * 2.1 + 9.0) * 0.5) * 4.8) * 0.5 + 0.5;
	float rip = smoothstep(0.9, 0.97, rp) * aa(0.18, gn(vec2(a * 0.9, sa * 0.4) + w * 1.3 + 11.0), 0.12);
	rip *= ripples * smoothstep(-0.5, 1.5, d) * (1.0 - smoothstep(reach * 0.4, reach * 1.4, d));
	ALBEDO = foam_color;
	if (world_light > 0.5) {
		// The world's light against its reference (the fall's world_lit:
		// shaders/waterfall_volume.gdshader), the key more the higher it stands.
		vec3 key = zs_key_irradiance / mix(vec3(1.0), vec3(1.432, 0.927, 0.454), 0.6);
		vec3 fill = zs_hemi_sky * zs_hemi_energy / mix(vec3(1.0), vec3(0.801, 1.025, 1.336), 0.6);
		ALBEDO *= (key * (0.55 + 0.65 * smoothstep(-0.05, 0.5, zs_key_direction.y)) + fill) / 3.446 * world_gain;
	}
	ALPHA = clamp(max(foam * 0.97, rip * 0.3), 0.0, 1.0);
}
