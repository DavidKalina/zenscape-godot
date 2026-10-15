shader_type sky;
// The oculus sky (scripts/underground/underground.gd, preset `oculus`;
// docs/design/roguelike/underground-oculus-round1.md): the underground seen
// from the dark. Above, a dark cavern roof with one vast round opening that
// the run climbs toward, the real opal sky and cloud in it, bright against
// the vault; the roof round its rim catching spill light. Below, the abyss
// filled with a slow mist sea lit faintly from within, the horizon the city
// lacked. Everything is traced from the camera (POSITION), so the opening
// has true parallax, grows as the wanderer climbs toward it, and is seen
// foreshortened when it lies off to one side.
// No far walls and no made-up structures: roof, opening, mist.
uniform vec3 oculus = vec3(0.0, 400.0, 0.0);   // the opening's centre (world)
uniform float radius = 160.0;                  // its radius (m)
uniform float cloud_height = 700.0;            // the cloud deck above the roof (m)
uniform float sea_y = -120.0;                  // the mist sea's surface (world y)
uniform vec3 sun_dir = vec3(0.3, 0.8, 0.5);    // toward the sun
uniform float glory = 1.0;                     // the opening's brightness gain
uniform float sea_glow = 1.0;                  // the mist's inner light
uniform float vault_lift = 1.0;                // the roof's own light
uniform vec3 vault_color : source_color = vec3(0.020, 0.030, 0.040);
uniform vec3 spill_color : source_color = vec3(1.0, 0.70, 0.42);
uniform vec3 haze_color : source_color = vec3(0.10, 0.16, 0.18);
uniform vec3 sea_deep : source_color = vec3(0.07, 0.15, 0.17);
uniform vec3 sea_pale : source_color = vec3(0.50, 0.70, 0.70);
uniform vec3 pool_at = vec3(0.0, 0.0, 0.0);    // where the shaft lands (world), the sea lit under it
uniform float haze_reach = 1500.0;             // m to the horizon's full haze

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
// Fractal noise whose finer octaves fade where they would shimmer (`blur`
// is the pattern's footprint per pixel, in cells).
float fbm(vec2 p, float blur) {
	float s = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) {
		float keep = 1.0 - smoothstep(0.25, 0.7, blur);
		s += a * mix(0.5, vn(p), i == 0 ? 1.0 : keep);
		p = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.07 + 11.3;
		blur *= 2.07;
		a *= 0.5;
	}
	return s;
}

// The real sky through the opening: opal, clouds seen from below with their
// edges lit, a bright glory about the sun.
vec3 sky_through(vec3 d, vec3 sun) {
	float up = max(d.y, 0.12);
	vec2 uv = (d.xz / up) * 7.0 + vec2(TIME * 0.02, TIME * 0.008);
	// The deep blue overhead pales toward the rim and warms toward the sun.
	vec3 zenith = vec3(0.20, 0.36, 0.92);
	vec3 pearl = vec3(1.05, 0.90, 1.00);
	float low = 1.0 - smoothstep(0.1, 0.85, d.y);
	vec3 col = mix(zenith, pearl, low * 0.8);
	float toward = max(dot(d, sun), 0.0);
	col += vec3(1.0, 0.82, 0.58) * (pow(toward, 6.0) * 0.55 + pow(toward, 90.0) * 1.8);
	// Clouds: broad masses and a finer grain; lit from the sun's side.
	float blur = 0.012 * 7.0 / up;
	float c = fbm(uv, blur);
	float lit = fbm(uv + sun.xz * 0.22 / up, blur);
	float cover = smoothstep(0.44, 0.68, c);
	float edge = clamp((c - lit) * 5.0 + 0.45, 0.0, 1.0);
	vec3 cloud_top = mix(vec3(0.9, 0.9, 1.0), vec3(2.0, 1.7, 1.35), edge);
	vec3 cloud_core = vec3(0.48, 0.46, 0.70);
	vec3 cl = mix(cloud_top, cloud_core, smoothstep(0.62, 0.95, c) * (1.0 - edge));
	cl += vec3(1.0, 0.72, 0.62) * pow(1.0 - cover, 2.0) * edge * 0.25;
	col = mix(col, cl, cover * (0.45 + 0.55 * smoothstep(0.1, 0.5, d.y)));
	return col;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 sun = normalize(sun_dir);
	vec3 col;
	vec3 haze = haze_color;
	if (d.y < -0.002) {
		// --- The mist sea: a cloud floor far below, lit from within. ---
		float t = (sea_y - POSITION.y) / d.y;
		vec2 p = POSITION.xz + d.xz * t;
		float blur = clamp(t * 0.0001, 0.0, 2.5);
		vec2 q = p * 0.006 + vec2(TIME * 0.0035, -TIME * 0.0015);
		float warp = vn(q * 0.7 + TIME * 0.002);
		float m = fbm(q + warp * 1.2, blur);
		// Heaped billows: soft ridges where puffs meet, pale crowns, deep hollows.
		float ridge = 1.0 - abs(2.0 * fbm(q * 0.8 + warp * 0.8 + 5.0, blur) - 1.0);
		float puff = smoothstep(0.38, 0.74, mix(m, ridge, 0.35));
		vec3 sea = mix(sea_deep, sea_pale, puff);
		sea *= 0.5 + 0.95 * puff;
		sea = mix(sea, vec3(dot(sea, vec3(0.33))) * vec3(0.95, 1.05, 1.03), 0.25);
		// The mist is warmed where the daylight falls on it.
		float pool = exp(-pow(length(p - pool_at.xz) / 230.0, 2.0));
		sea = mix(sea, sea * vec3(1.5, 1.25, 0.95) + spill_color * 0.04, pool * 0.7);
		sea *= sea_glow;
		// Toward the horizon it goes to haze, a pale line to set the city against.
		float far = 1.0 - exp(-pow(t / haze_reach, 0.8));
		col = mix(sea, haze * 1.7 + sea_pale * 0.1 * sea_glow, far);
	} else {
		// --- The roof: a plane at the opening's height, traced. ---
		float t = (oculus.y - POSITION.y) / max(d.y, 0.0005);
		vec2 p = POSITION.xz + d.xz * t;
		vec2 rel = p - oculus.xz;
		float r = length(rel);
		float phi = atan(rel.y, rel.x);
		// The rim is not a circle: lobes and bites, quiet in the middle distance.
		float wob = (vn(vec2(phi * 3.0, 1.7)) - 0.5) * 0.22 + (vn(vec2(phi * 9.0, 4.1)) - 0.5) * 0.09 + (vn(vec2(phi * 23.0, 8.3)) - 0.5) * 0.03;
		float R = radius * (1.0 + wob);
		float inside = 1.0 - smoothstep(-R * 0.012, 0.0, r - R);   // 1 in the opening
		float over = r - R;                                     // m past the rim
		// Roof rock: ribs running out from the opening and coarse facets, lit
		// by the spill that decays with distance from the rim.
		float foot = clamp(t * 0.00006, 0.0, 2.0);
		// Broad slabs and fault lines, not ripples: the roof is big rock.
		float slabs = fbm(p * 0.0045 + vec2(3.1, 7.7), foot * 1.0);
		float crack = (1.0 - smoothstep(0.0, 0.09, abs(fbm(p * 0.007 + vec2(9.0, 2.0), foot * 2.0) - 0.5))) * smoothstep(0.35, 0.6, fbm(p * 0.02, foot * 3.0));
		float ribs = fbm(vec2(phi * 4.0 + over * 0.002, over * 0.006), foot * 1.0);
		float rock = clamp(mix(slabs, ribs, 0.4) * 1.25 - crack * 0.22 + (fbm(p * 0.02, foot * 3.0) - 0.5) * 0.25, 0.0, 1.0);
		float spill = exp(-max(over, 0.0) / (radius * 0.4)) * (0.2 + 1.0 * smoothstep(0.4, 0.8, rock));
		float rimline = exp(-max(over, 0.0) / (radius * 0.05));
		vec3 vault = vault_color * (0.7 + 1.0 * rock) + vec3(0.016, 0.034, 0.038) * (0.4 + rock) * vault_lift;
		vault += spill_color * (spill * 0.12 + rimline * 0.2) * vault_lift * glory;
		vault += vec3(0.22, 0.34, 0.36) * spill * 0.05 * vault_lift;
		// Far roof sinks into the cavern's haze, and cavern air lifts it a little.
		float far = 1.0 - exp(-t / (haze_reach * 1.6));
		vault = mix(vault, haze * 0.9, far);
		// The sky through the opening, seen from below.
		vec3 through = sky_through(d, sun) * glory;
		// A rim glory: inside the edge the sky is brightest, the rock a hard dark line.
		float edge_in = exp(-max(-over, 0.0) / (radius * 0.07));
		through *= 1.0 + 0.25 * edge_in;
		col = mix(vault, through, inside);
		// Lens glow just past the rim (bloom does the rest).
		col += spill_color * exp(-max(over, 0.0) / (radius * 0.12)) * 0.03 * glory * step(0.0, over);
		// Grazing rays to the horizon: dim haze, the roof going away.
		col = mix(col, haze * 1.4, smoothstep(0.22, 0.0, d.y) * 0.85);
	}
	// A pale line of mist-light where roof meets sea: the horizon the city sets itself against.
	col = mix(col, haze * 2.3 + sea_pale * 0.05, exp(-abs(d.y) * 22.0) * 0.55);
	COLOR = col;
}
