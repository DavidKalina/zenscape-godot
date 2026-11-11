shader_type spatial;
// The railroad's track (scripts/endless/rail_track.gd, rail_wear.gd): ballast,
// sleepers and rails, weathered from the mesh's own coordinates and one shared
// wear map (no per-piece texture, so a piece looks the same near and far).
// UV is across the track in m from its centre (the rails' own: from the rail's
// middle) and along the line's s; UV2 is a part's own numbers (sleepers: a
// number for the sleeper and its middle s; rails: top or side, and height).
// Lit as the world is: no ambient, the sky's hemisphere added as emission.
//   mode 0 ballast: crushed stone with relief, dark and oily down the middle
//     of the track, pale at the shoulders, weeds and dust at the foot. It
//     also paints the sleepers and the rails (anti-aliased, fading to their
//     mean), so the far strip, which has no sleepers or rails built, reads as
//     the same track.
//   mode 1 sleepers: timber with grain, a tone for each, oil and soot down
//     the middle between the rails, some pale, some split.
//   mode 2 rails: a polished running surface, rusty sides and foot.
render_mode diffuse_lambert, specular_schlick_ggx;
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
uniform int mode = 0;
uniform sampler2D wear_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float fill = 3.2;
uniform float rim = 0.0;
// Per piece of the line: 1.6 m between sleepers (rail_track.gd SLEEPER_STEP),
// their half width and half length, the gauge.
uniform float pitch = 1.6;
uniform float sleeper_half_width = 0.25;
uniform float sleeper_half = 2.3;
uniform float rail_half_gauge = 1.5;
uniform float rail_half_width = 0.15;
varying vec3 wpos;
varying float depth;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}
float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}
void fragment() {
	float far = smoothstep(40.0, 320.0, depth);
	// The strip's shoulders carry an inward normal (the quads' winding): the ballast
	// all faces up, so take the geometry's own normal and turn it to the sky.
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (mode == 0) {
		wn = normalize(cross(dFdx(wpos), dFdy(wpos)));
		if (wn.y < 0.0) wn = -wn;
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	}
	float a = UV.x;
	float s = UV.y;
	vec3 col = COLOR.rgb;
	float rough = 0.9;
	float metal = 0.0;
	float shade = 1.0;
	// One set of blotches at three scales, tiled over the world, never twice alike
	// side by side: noise R wide, G medium, B fine.
	vec2 w2 = wpos.xz;
	float wide = texture(wear_tex, w2 * 0.021 + 0.31).r * 0.55 + texture(wear_tex, w2 * 0.067 + 0.7).r * 0.45;
	float mid = texture(wear_tex, w2 * 0.31).g;
	if (mode == 0) {
		// Crushed stone: many small stones, each its own grey or tan.
		vec4 st = texture(wear_tex, w2 * 1.1);
		vec4 st2 = texture(wear_tex, w2 * 3.4 + 0.5);
		float grit = mix(st.b, 0.5, far * 0.7);
		float stones = mix(st2.b, 0.5, far);
		float chip = smoothstep(0.38, 0.62, grit) * 0.55 + stones * 0.45;
		vec3 dark = vec3(0.13, 0.125, 0.12);
		vec3 pale = col * vec3(1.12, 1.07, 1.0);
		vec3 b = mix(dark, pale, chip);
		// A crack between stones, a little shadow that gives relief.
		b *= 1.0 - 0.35 * (1.0 - smoothstep(0.16, 0.36, st.g)) * (1.0 - far);
		b *= 0.88 + 0.28 * (mid - 0.5);
		float ac = abs(a);
		// Darker and oilier down the track's middle, the stains in blotches.
		float oil = smoothstep(1.8, 0.2, ac) * (0.25 + 0.75 * smoothstep(0.35, 0.7, wide));
		b = mix(b, b * vec3(0.6, 0.57, 0.55), clamp(oil, 0.0, 1.0));
		// Paler and dustier toward the shoulders; it is fresh stone where trains don't drip.
		float sh = smoothstep(2.0, 2.9, ac);
		b = mix(b, b * vec3(1.18, 1.14, 1.06) + 0.02, sh * 0.8);
		// Where it meets the land: dust, then weeds in tufts.
		float edge = smoothstep(2.9, 3.6, ac);
		vec3 weed = mix(vec3(0.09, 0.11, 0.045), vec3(0.17, 0.15, 0.07), texture(wear_tex, w2 * 0.9).g);
		float tuft = smoothstep(0.42, 0.62, wide * 0.6 + st.g * 0.5);
		b = mix(b, mix(b * 0.9, weed, tuft), edge * (0.55 + 0.45 * tuft));
		// The sleepers and the rails, painted: their footprints, anti-aliased.
		float aa = max(fwidth(s), 0.0005);
		float ph = abs(fract(s / pitch + 0.5) - 0.5) * pitch;
		float band = 1.0 - smoothstep(sleeper_half_width - aa * 0.5, sleeper_half_width + aa * 0.5, ph);
		float mean_band = sleeper_half_width * 2.0 / pitch;
		float w = smoothstep(0.25, 0.9, aa / pitch);
		band = mix(band, mean_band, w);
		float across_s = 1.0 - smoothstep(sleeper_half - 0.1, sleeper_half + 0.1, ac);
		float tone = 0.8 + 0.5 * hash11(floor(s / pitch + 0.5) * 1.7 + 3.1);
		vec3 tim = vec3(0.12, 0.085, 0.06) * tone;
		b = mix(b, tim, band * across_s * 0.92);
		float aa2 = max(fwidth(a), 0.0005);
		float rl = 1.0 - smoothstep(rail_half_width - aa2 * 0.5, rail_half_width + aa2 * 0.5, abs(ac - rail_half_gauge));
		float rl_mean = rail_half_width * 2.0 / max(aa2 * 2.0, rail_half_width * 2.0);
		rl = mix(rl, min(rl_mean, 1.0), smoothstep(0.15, 0.6, aa2 / (rail_half_width * 2.0)));
		vec3 rail_c = vec3(0.28, 0.2, 0.16);
		b = mix(b, rail_c, rl * 0.9);
		col = b;
		rough = 0.95 - 0.28 * clamp(oil, 0.0, 1.0) * (1.0 - far) + 0.05 * (mid - 0.5);
	} else if (mode == 1) {
		float id = UV2.x;
		float local = s - UV2.y;
		float pale_one = step(0.8, hash11(id * 91.0 + 7.0));
		float grey_one = step(0.6, hash11(id * 53.0 + 1.0));
		float tone = 0.55 + 0.95 * id;
		vec3 t = col * tone;
		t = mix(t, vec3(dot(t, vec3(0.3, 0.55, 0.15))), 0.25);
		t = mix(t, vec3(0.30, 0.26, 0.21) * (0.7 + 0.5 * id), grey_one * 0.55);
		t = mix(t, vec3(0.36, 0.29, 0.21), pale_one * 0.7);
		// Grain runs along the sleeper (across the track), with fine raised lines.
		float grain = texture(wear_tex, vec2(a * 0.18 + id * 5.0, local * 6.5 + id * 3.0)).g;
		float fine = texture(wear_tex, vec2(a * 0.9 + id * 2.0, local * 31.0)).b;
		t *= mix(1.0, 0.65 + 0.7 * grain, 1.0 - far * 0.8);
		t *= mix(1.0, 0.8 + 0.4 * fine, 1.0 - far);
		// Bleached and checked at the ends, where the grain opens.
		float ac = abs(a);
		float endg = smoothstep(1.9, 2.3, ac);
		t = mix(t, t * 1.25 + 0.03, endg * 0.7);
		// A split, along the grain on some sleepers: a dark line, broken up.
		float sp = hash11(id * 37.0 + 11.0);
		float where = (sp - 0.5) * 0.35;
		float crack = (1.0 - smoothstep(0.006, 0.02, abs(local - where))) * step(0.72, hash11(id * 13.0 + 5.0));
		crack *= smoothstep(0.35, 0.6, texture(wear_tex, vec2(a * 0.4 + id * 9.0, 0.5)).r);
		t *= 1.0 - 0.8 * crack;
		// Oil and soot down the middle between the rails.
		float oil = smoothstep(1.9, 0.5, ac) * (0.4 + 0.9 * smoothstep(0.3, 0.7, texture(wear_tex, vec2(a * 0.12, id * 3.7)).r + 0.2 * grain));
		t *= 1.0 - 0.6 * clamp(oil, 0.0, 1.0);
		// Under the rails, a darker, polished patch where the plates sit.
		float plate = 1.0 - smoothstep(0.35, 0.6, abs(ac - rail_half_gauge));
		t *= 1.0 - 0.3 * plate;
		col = t;
		rough = 0.88 - 0.4 * clamp(oil, 0.0, 1.0) + 0.1 * (grain - 0.5);
	} else {
		float top = UV2.x;
		float h = UV2.y;
		float ac = abs(a);
		float along = texture(wear_tex, vec2(s * 0.06, a * 0.5)).g;
		float blot = texture(wear_tex, vec2(s * 0.017 + 0.3, 0.25)).r;
		float tiny = texture(wear_tex, vec2(s * 0.7, a * 3.0 + h * 4.0 + 0.1)).b;
		float rust = clamp(0.5 + 0.7 * (blot - 0.5) + 0.5 * (along - 0.5), 0.0, 1.0);
		vec3 rusty = mix(vec3(0.17, 0.105, 0.075), vec3(0.34, 0.19, 0.11), rust);
		rusty *= 0.8 + 0.4 * tiny;
		// The sides and foot are dark rust, wetter and darker at the foot.
		rusty *= mix(0.75, 1.0, h);
		vec3 steel = vec3(0.5, 0.5, 0.5) * (0.85 + 0.3 * along);
		// The running surface, polished by the wheels along its middle.
		float run = (1.0 - smoothstep(0.07, 0.125, ac)) * top;
		float edge_rust = (1.0 - run) * top * 0.75;
		vec3 c2 = mix(rusty, steel, run);
		c2 = mix(c2, rusty * 1.2, edge_rust * 0.4);
		// A dull stretch where a rail is dry, brighter where wheels ran this morning.
		c2 *= 0.85 + 0.3 * smoothstep(0.3, 0.7, blot);
		col = c2;
		rough = mix(0.82, 0.28, run) + 0.15 * (tiny - 0.5);
		metal = 0.0;
	}
	// The shaded side weighs more: darker where it faces down.
	col *= mix(0.62, 1.0, smoothstep(-0.9, 0.2, wn.y));
	ALBEDO = col;
	ROUGHNESS = clamp(rough, 0.12, 1.0);
	METALLIC = metal;
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, wn.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	EMISSION = col * (hemi * fill + (fill > 0.0 ? 0.035 : 0.0)) + col * zs_hemi_sky * zs_hemi_energy * edge * rim;
}
