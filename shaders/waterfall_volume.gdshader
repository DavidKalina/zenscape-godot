shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled, depth_draw_never, depth_test_disabled, blend_mix;
// A waterfall as a thick body (study: studies/waterfall_study.tscn), marched
// inside a box by an ordinary spatial shader (the way flame_volume.gdshader
// is). It is a fluid, not a cloud: the density is a solid body with its front
// carved into ropes and ribs by noise stretched hard along the fall, so the
// first sample that is inside the water is the surface (opaque, a hard
// silhouette, depth written so rock and the pool sort against it). Then the
// surface is shaded: a gradient normal, the sun, a short shadow ray so ribs
// shade one another, troughs darker, fine falling streaks, pale blue-grey in
// the shade, white at the lit crests, whiter and denser in the churn at the
// base.
//
// The box is in "fall space": x across the fall (centred), y up from the
// pool (0 at the foot), z out from the wall (0 at the wall face). The mesh is
// a box of `box_size` whose centre is at (0, box_size.y/2, box_size.z/2) from
// the node's origin, so the node's origin is the wall face at the foot.
// The water flows out over the lip horizontally, curves over in a quarter
// circle and falls; the noise runs along that path so strands bend with it.

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 box_size = vec3(28.0, 42.5, 6.6);
// Half the width of the fall (m), the lip's top (m up from the foot), the
// front of the falling water (m out from the wall).
uniform float half_width = 13.0;
uniform float lip_y = 41.2;
uniform float front_z = 4.0;
// Radius (m) of the curve where the water bends over the lip.
uniform float curve_radius : hint_range(0.5, 6.0) = 2.2;
// How deep the body is behind its front (m).
uniform float thickness : hint_range(0.5, 8.0) = 5.0;
// Strand columns per metre across the fall (bigger: finer ropes).
uniform float streak_scale : hint_range(0.5, 6.0) = 1.7;
// How much longer a strand is than it is wide.
uniform float streak_stretch : hint_range(2.0, 40.0) = 12.0;
// Metres per second the layers fall near the lip (back layer 0.55x, front 1.25x).
uniform float fall_speed : hint_range(0.0, 30.0) = 7.0;
// How much faster it falls toward the bottom (0 none).
uniform float fall_accel : hint_range(0.0, 4.0) = 1.5;
// How far the front is carved into ropes (0 a smooth slab, 1 deeply ribbed).
uniform float surface_relief : hint_range(0.0, 1.0) = 0.85;
// Metres in from each side over which the body thins into separate strands.
uniform float edge_break : hint_range(0.0, 4.0) = 1.6;
// Height (m) of the churn at the foot, where it is denser and whiter.
uniform float churn_height : hint_range(0.0, 8.0) = 3.0;
// How far the churn bulges out past the front (m).
uniform float churn_bulge : hint_range(0.0, 3.0) = 1.0;
// White to pale blue-grey: how far down the shading goes.
uniform float shade_range : hint_range(0.0, 1.0) = 0.75;
// March steps through the box (more: finer thin strands at grazing angles).
uniform int steps : hint_range(8, 96) = 40;
// World direction toward the sun.
uniform vec3 sun_dir = vec3(0.3, 0.7, 0.65);
uniform vec3 white_color : source_color = vec3(0.98, 0.99, 1.0);
uniform vec3 shade_color : source_color = vec3(0.55, 0.68, 0.80);

varying vec3 v_local;
varying vec3 v_cam;

void vertex() {
	v_local = VERTEX + vec3(0.0, box_size.y * 0.5, box_size.z * 0.5);
	v_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz + vec3(0.0, box_size.y * 0.5, box_size.z * 0.5);
}

float h31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x),
			mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x),
			mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// Distance along the fall warped so patterns stretch toward the bottom.
float warp(float d) {
	float k = fall_accel / max(front_z + lip_y, 1.0);
	return log(1.0 + k * d) / max(k, 0.0001);
}

// The water's own frame at a point: s metres along the flow from where it
// leaves the wall, q metres out from the front surface (0 on it, negative
// inside). Horizontal over the lip, a quarter circle, then straight down.
void flow(vec3 P, out float s, out float q) {
	float yc = lip_y - curve_radius;
	float zc = front_z - curve_radius;
	if (P.y <= yc) {
		s = curve_radius * 1.5707963 + (yc - P.y);
		q = P.z - front_z;
	} else if (P.z <= zc) {
		s = P.z - zc;
		q = P.y - lip_y;
	} else {
		vec2 d = vec2(P.z - zc, P.y - yc);
		q = length(d) - curve_radius;
		s = curve_radius * (1.5707963 - atan(d.y, d.x));
	}
}

// Positive inside the water. The body is solid; only near its front is it
// carved by noise (ropes) and near its sides is it thinned into strands.
float field(vec3 P) {
	float s, q;
	flow(P, s, q);
	float sw = s < 0.0 ? s : warp(s);
	float T = TIME * fall_speed;
	float cx = streak_scale;
	float st = streak_stretch;
	vec3 a = vec3(P.x * cx, (sw - T * 0.55) * cx / st, q * cx * 0.8);
	vec3 b = vec3(P.x * cx * 1.9 + 11.0, (sw - T * 1.25) * cx * 1.9 / st + 5.0, q * cx * 1.4 + 3.0);
	float na = vnoise(a) * 0.7 + vnoise(a * 2.3 + 7.0) * 0.3;
	float nb = vnoise(b);
	float n = mix(na, nb, smoothstep(-2.6, -0.3, q));

	// The foot: a dense churn (unstretched noise, solid, bulging).
	float cb = 1.0 - smoothstep(0.0, max(churn_height, 0.01), P.y);
	float cn = vnoise(vec3(P.x * 0.7, P.y * 0.9 - TIME * 2.5, P.z * 0.9));
	n = mix(n, 0.45 + cn * 0.5, cb * 0.7);

	// Ropes: the nearer the front, the higher the bar the noise must clear.
	float thr = surface_relief * 0.72 * smoothstep(-2.3, 0.0, q) * smoothstep(1.0, 6.0, s);
	thr *= 1.0 - 0.85 * cb;
	// Sides: strands thin out toward the edge, each at its own pace.
	float e = half_width - abs(P.x);
	thr = max(thr, 0.95 * (1.0 - smoothstep(0.0, max(edge_break, 0.01), e)));

	float cap = churn_bulge * cb * clamp((cn - 0.2) * 2.6, -0.3, 1.4);
	float v = n - thr;
	v = min(v, (cap - q) * 0.5);
	v = min(v, (e + 0.2) * 0.5);
	v = min(v, (thickness + q) * 0.5);
	v = min(v, P.z * 2.0 + 0.1);
	v = min(v, P.y * 2.0);
	return v;
}

float ign(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	vec3 ro = v_cam;
	vec3 rd = normalize(v_local - v_cam);
	vec3 bmin = vec3(-box_size.x * 0.5, 0.0, 0.0);
	vec3 bmax = vec3(box_size.x * 0.5, box_size.y, box_size.z);
	vec3 inv = 1.0 / (rd + vec3(1e-6));
	vec3 ta = (bmin - ro) * inv;
	vec3 tb = (bmax - ro) * inv;
	vec3 tmn = min(ta, tb);
	vec3 tmx = max(ta, tb);
	float t0 = max(max(tmn.x, tmn.y), max(tmn.z, 0.0));
	float t1 = min(min(tmx.x, tmx.y), tmx.z);
	if (t1 <= t0) discard;

	float dt = (t1 - t0) / float(steps);
	float t = t0 + dt * ign(FRAGCOORD.xy);
	float tp = t0;
	bool hit = false;
	for (int i = 0; i < 96; i++) {
		if (i >= steps) break;
		if (field(ro + rd * t) > 0.0) {
			hit = true;
			break;
		}
		tp = t;
		t += dt;
	}
	if (!hit) discard;
	// Settle on the surface between the last miss and the first hit.
	for (int j = 0; j < 5; j++) {
		float tm = 0.5 * (tp + t);
		if (field(ro + rd * tm) > 0.0) t = tm; else tp = tm;
	}
	vec3 p = ro + rd * t;

	// Behind the rock or the ground? Then it is hidden (the water draws in
	// the transparent pass, after them, and compares against their depth).
	vec3 wp = (MODEL_MATRIX * vec4(p - vec3(0.0, box_size.y * 0.5, box_size.z * 0.5), 1.0)).xyz;
	float sd = texture(depth_tex, SCREEN_UV).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, sd, 1.0);
	sv.xyz /= sv.w;
	if ((VIEW_MATRIX * vec4(wp, 1.0)).z < sv.z) discard;

	// Normal from the field's gradient.
	float e = 0.12;
	float v0 = field(p);
	vec3 g = vec3(field(p + vec3(e, 0, 0)) - v0, field(p + vec3(0, e, 0)) - v0, field(p + vec3(0, 0, e)) - v0);
	vec3 n = -normalize(g + vec3(1e-5));
	vec3 nw = normalize(mat3(MODEL_MATRIX) * n);
	vec3 L = normalize(sun_dir);
	vec3 Lf = normalize(transpose(mat3(MODEL_MATRIX)) * L);

	// Shadow: do the ribs and the lip's curve block the sun? Three taps.
	float occ = 0.0;
	vec3 so = p + n * 0.2;
	occ += field(so + Lf * 0.45) > 0.0 ? 1.0 : 0.0;
	occ += field(so + Lf * 1.1) > 0.0 ? 1.0 : 0.0;
	occ += field(so + Lf * 2.4) > 0.0 ? 1.0 : 0.0;
	float sun = clamp(dot(nw, L) * 0.85 + 0.2, 0.0, 1.0) * (1.0 - 0.75 * min(occ / 2.0, 1.0));
	float sky = 0.5 + 0.5 * nw.y;
	float lit = clamp(sun * 0.75 + sky * 0.2, 0.0, 1.0);

	float s, q;
	flow(p, s, q);
	float sw = s < 0.0 ? s : warp(s);
	float T = TIME * fall_speed;
	// Troughs are darker; fine streaks run down the surface.
	float trough = 1.0 - smoothstep(-2.0, -0.1, q);
	float fine = vnoise(vec3(p.x * streak_scale * 5.0, (sw - T * 1.1) * streak_scale * 5.0 / (streak_stretch * 1.4), q * 2.0));
	float shade = (1.0 - lit) * 1.5 + trough * 0.4 + (0.5 - fine) * 0.4;
	float edge_thin = 1.0 - smoothstep(0.0, max(edge_break, 0.01), half_width - abs(p.x));
	shade += edge_thin * 0.25;
	float cb = 1.0 - smoothstep(0.0, max(churn_height, 0.01), p.y);
	shade *= 1.0 - 0.8 * cb;
	shade = clamp(shade * shade_range, 0.0, 1.0);
	ALBEDO = mix(white_color, shade_color, shade);
	ALPHA = 1.0;

}
