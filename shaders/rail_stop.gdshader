shader_type spatial;
// The railroad's stops (scripts/endless/rail_stops.gd, rail_wear.gd): the
// station, the depot and the town's buildings, the tower, the fences, weathered
// from the mesh's own coordinates and one shared wear map. A face is its
// vertex colour (the paint) worn here. UV: along the face in m (a side: along
// it, then down from the box's top; a top: the box's own two axes). UV2.x is
// the kind of part, UV2.y its height over the ground it stands on (99 when it
// stands on another part). Lit as the world is: no ambient, the sky's
// hemisphere as emission. Kinds: 0 painted boards, 1 platform, 2 timber,
// 3 roof, 4 tank, 5 trim, 6 brick, 7 window glass, 8 door, 9 stone foot.
render_mode diffuse_lambert, specular_schlick_ggx;
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
uniform sampler2D wear_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float fill = 2.2;
uniform float rim = 0.0;
varying float depth;
varying vec3 wpos;
void vertex() {
	depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float lines(float x, float width, float period, float aa) {
	// A thin line each `period`, `width` wide, fading to its mean as it gets finer than a pixel.
	float f = abs(fract(x / period + 0.5) - 0.5) * period;
	float px = max(fwidth(x), 0.0005);
	float l = 1.0 - smoothstep(width * 0.5 - px * 0.5, width * 0.5 + px * 0.5, f);
	float mean_l = width / period;
	return mix(l, mean_l, smoothstep(0.3, 0.9, px / period));
}
void fragment() {
	float far = smoothstep(30.0, 200.0, depth);
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float kind = UV2.x + 0.5;
	float gh = UV2.y;
	// On a top UV2.y is its half sizes (quarter metres: x + 512 z); the distance in from its edge.
	float edge_in = 99.0;
	if (wn.y > 0.7) {
		float hzq = floor(UV2.y / 512.0);
		float hxq = UV2.y - hzq * 512.0;
		edge_in = min(hxq * 0.25 - abs(UV.x), hzq * 0.25 - abs(UV.y));
		gh = 99.0;
	}
	vec2 uv = UV;
	bool top = wn.y > 0.7;
	bool under = wn.y < -0.7;
	vec3 col = COLOR.rgb;
	float shelter = COLOR.a;
	float rough = 0.9;
	// Each face's wear: big patches and the fine scatter, from the world and the face.
	float patch = texture(wear_tex, uv * 0.11 + wpos.xz * 0.013).r;
	float patch2 = texture(wear_tex, uv * 0.33 + 0.4).g;
	float grit = mix(texture(wear_tex, uv * 2.9).b, 0.5, far);
	float luma = dot(col, vec3(0.3, 0.55, 0.15));
	float drip_x = texture(wear_tex, vec2(uv.x * 0.8, 0.31)).g;
	// Rain streaks off an eave or a sill: a running wash, strongest just under the top.
	float run = texture(wear_tex, vec2(uv.x * 1.3, uv.y * 0.05 + 0.2)).g;
	float below_top = clamp(-uv.y, 0.0, 6.0);
	float streak_k = smoothstep(0.55, 0.78, run) * (1.0 - smoothstep(0.5, 6.0, below_top)) * (1.0 - float(top || under));
	float low = 1.0 - smoothstep(0.1, 1.6, gh);
	float damp = 1.0 - smoothstep(0.0, 0.7, gh);
	if (kind < 1.0) {
		// Painted boards, faded and chalky, lighter in patches, flaking dark.
		col *= 0.56 + 0.4 * patch;
		col = mix(col, vec3(luma * 1.05), 0.04 * smoothstep(0.45, 0.75, patch2));
		float board = lines(uv.y, 0.03, 0.22, 0.0) * (1.0 - far);
		col *= 1.0 - 0.22 * board;
		col *= 1.0 - 0.15 * smoothstep(0.55, 0.9, grit) * (1.0 - far);
		col = mix(col, col * vec3(0.55, 0.5, 0.45), 0.7 * streak_k);
		// Grime low down, with the splash and the damp at the foot.
		col = mix(col, col * vec3(0.5, 0.46, 0.4), clamp(low * (0.4 + 0.6 * patch2), 0.0, 1.0) * 0.8);
		rough = 0.74 + 0.22 * grit + 0.1 * streak_k;
	} else if (kind < 2.0) {
		// Platform: a worn slab, hairline cracks, stained, grimed at its edges.
		float c1 = texture(wear_tex, uv * 0.45 + 0.15).g;
		col *= 0.7 + 0.45 * patch;
		float crack = (1.0 - smoothstep(0.008, 0.02, abs(c1 - 0.5))) * 0.3;
		col *= 1.0 - crack * (1.0 - far);
		float oil = smoothstep(0.6, 0.82, patch2) * 0.3;
		col *= 1.0 - oil;
		float seam = lines(uv.y, 0.06, 4.0, 0.0) * float(top) * (1.0 - far);
		col *= 1.0 - 0.25 * seam;
		float rim_g = (1.0 - smoothstep(0.0, 0.9, edge_in)) * float(top);
		col = mix(col, col * vec3(0.5, 0.47, 0.42), (low * 0.6 + (1.0 - float(top)) * 0.25 + 0.5 * rim_g) * (0.5 + 0.5 * patch2));
		rough = 0.88 - 0.3 * oil + 0.06 * (grit - 0.5);
	} else if (kind < 3.0 || (kind >= 4.0 && kind < 5.0)) {
		// Timber: grain up the board, grey where the sun bleaches it, dark with damp low down.
		float grain = texture(wear_tex, vec2(uv.x * 2.2, uv.y * 0.12 + patch * 0.8)).g;
		float fine = texture(wear_tex, vec2(uv.x * 9.0, uv.y * 0.55)).b;
		col *= 0.6 + 0.8 * grain;
		col *= mix(1.0, 0.78 + 0.35 * fine, 1.0 - far);
		float silver = smoothstep(0.35, 0.75, patch);
		col = mix(col, vec3(luma * 1.05) * vec3(1.04, 1.0, 0.94) + 0.03, 0.35 * silver);
		float board = lines(uv.x, 0.03, 0.3, 0.0) * (1.0 - far) * float(kind > 3.5 && !top);
		col *= 1.0 - 0.35 * board;
		col = mix(col, col * vec3(0.55, 0.5, 0.45), 0.75 * damp);
		col = mix(col, col * vec3(0.55, 0.5, 0.45), 0.7 * streak_k);
		rough = 0.86 + 0.1 * (grain - 0.5);
		if (kind >= 4.0) {
			// The tank: iron hoops, rusting, with the rust running down below each.
			float hp = 1.35;
			float hoop = lines(uv.y - 0.4, 0.14, hp, 0.0) * float(!top && !under);
			float under_h = fract((uv.y - 0.4) / hp);
			float run_below = smoothstep(0.1, 0.5, under_h) * (1.0 - smoothstep(0.5, 1.0, under_h)) * smoothstep(0.55, 0.85, run);
			vec3 rust = mix(vec3(0.17, 0.07, 0.035), vec3(0.34, 0.16, 0.07), patch2);
			col = mix(col, rust, clamp(hoop, 0.0, 1.0));
			col = mix(col, col * vec3(0.7, 0.45, 0.32), 0.7 * run_below * (1.0 - hoop) * float(!top && !under));
			rough = mix(rough, 0.55, hoop);
		}
	} else if (kind < 4.0) {
		// Roof: corrugated or shingled courses, rust along its edges and its seams
		// and running down, soot on top, and nothing blotched over the flat.
		float ribs = lines(top ? uv.x : uv.y, 0.12, 0.42, 0.0) * (1.0 - far);
		col *= 0.8 + 0.25 * patch;
		vec3 rust = mix(vec3(0.17, 0.07, 0.035), vec3(0.3, 0.13, 0.055), patch2);
		float near_edge = 1.0 - smoothstep(0.0, 1.1, edge_in);
		float rs = clamp(near_edge * (0.35 + 0.9 * smoothstep(0.35, 0.7, texture(wear_tex, wpos.xz * 0.9 + 0.7).g)) * float(top), 0.0, 1.0);
		rs = max(rs, 0.5 * (1.0 - far) * lines(top ? uv.x : uv.y, 0.05, 0.84, 0.0) * smoothstep(0.5, 0.75, patch2) * float(!under));
		col = mix(col, rust, 0.55 * rs);
		col *= 1.0 + 0.1 * ribs * float(top) - 0.1 * ribs * float(!top);
		col *= 1.0 - 0.18 * smoothstep(0.55, 0.9, grit) * (1.0 - far);
		col = mix(col, col * vec3(0.55, 0.45, 0.4), 0.6 * streak_k);
		rough = 0.6 + 0.3 * rs + 0.1 * grit;
	} else if (kind < 5.0) {
		col = col;
	} else if (kind < 6.0) {
		// Trim: more chalked and flaking than the boards, dirt in the corners.
		col *= 0.7 + 0.55 * patch;
		col = mix(col, col * vec3(0.5, 0.42, 0.34), 0.5 * smoothstep(0.55, 0.9, grit) * (1.0 - far));
		col = mix(col, col * vec3(0.55, 0.5, 0.45), 0.7 * streak_k);
		col = mix(col, col * vec3(0.5, 0.46, 0.4), low * 0.6);
		rough = 0.8 + 0.15 * grit;
	} else if (kind < 7.0) {
		// Brick: courses of brick with their mortar lines, soot and a white bloom.
		float course = 0.22;
		float row = floor(uv.y / course);
		float off = fract(row * 0.5) * 0.45;
		float mortar_y = lines(uv.y, 0.035, course, 0.0);
		float mortar_x = lines(uv.x + off * 0.5 * 2.0, 0.035, 0.45, 0.0);
		float mortar = clamp(mortar_y + mortar_x, 0.0, 1.0) * (1.0 - far);
		float tone = 0.65 + 0.7 * texture(wear_tex, vec2(floor((uv.x + off) / 0.45) * 0.137, row * 0.211)).g;
		col *= mix(1.0, tone, 1.0 - far * 0.8) * (0.8 + 0.4 * patch);
		col = mix(col, vec3(0.5, 0.46, 0.4), mortar * 0.75);
		col = mix(col, vec3(0.1, 0.09, 0.085), 0.5 * smoothstep(0.5, 0.85, patch2) * float(!top));
		col = mix(col, col * vec3(0.55, 0.5, 0.45), 0.6 * streak_k);
		col = mix(col, col * vec3(0.55, 0.5, 0.45), 0.7 * low);
		rough = 0.92 - 0.1 * mortar;
	} else if (kind < 8.0) {
		// Window glass: sky on its top, dirt along its foot and in streaks. gh is its height.
		float fr = clamp(-uv.y / max(gh, 0.1), 0.0, 1.0);
		float dirt = smoothstep(0.55, 0.85, run) * 0.45 + smoothstep(0.6, 1.0, fr) * 0.5;
		col = mix(col * 1.1 + vec3(0.02, 0.03, 0.04) * (1.0 - fr), vec3(0.14, 0.12, 0.1), clamp(dirt, 0.0, 1.0) * 0.6);
		rough = 0.18 + 0.4 * dirt;
	} else if (kind < 9.0) {
		// Door: boards, a dark worn threshold.
		float fr = clamp(-uv.y / max(gh, 0.1), 0.0, 1.0);
		float boards = lines(uv.x, 0.04, 0.3, 0.0);
		col *= (0.7 + 0.6 * patch) * (1.0 - 0.4 * boards);
		col = mix(col, col * 0.5, 0.6 * smoothstep(0.8, 1.0, fr));
		rough = 0.8;
	} else {
		// The stone foot: grey grit, damp and mossy at the ground.
		col *= 0.7 + 0.6 * patch;
		col *= 0.8 + 0.4 * grit;
		col = mix(col, vec3(0.1, 0.14, 0.06), 0.45 * damp * smoothstep(0.35, 0.75, patch2));
		rough = 0.95;
	}
	// Darker where it faces down or hides under a roof, so the shade has weight.
	col *= mix(0.55, 1.0, smoothstep(-0.9, 0.15, wn.y));
	col *= mix(0.55, 1.0, shelter);
	ALBEDO = col;
	ROUGHNESS = clamp(rough, 0.12, 1.0);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, wn.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	EMISSION = col * (hemi * fill + (fill > 0.0 ? 0.035 : 0.0)) + col * zs_hemi_sky * zs_hemi_energy * edge * rim;
}
