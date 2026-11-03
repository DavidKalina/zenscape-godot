shader_type spatial;
// The splash of a leaping fish (scripts/endless/wake_fish.gd): one instance is one
// splash, one mesh of a crown and quads, and all of it is worked out here from the
// moment it began, so a splash costs the CPU nothing once laid.
// The instance's origin: the spot on the water. Its first basis column: the fish's
// velocity there (m/s).
// INSTANCE_CUSTOM: x the moment it began (`clock`'s s), y its size (about 1 for
// 0.6 m of fish), z 1 going in, 0 coming out, w a seed.
// COLOR: r the sort (0 the crown, 0.25 a thrown drop, 0.5 a drop shed along the
// fish's path, 0.75 the jet, 1 a puff), g its heading (of a turn), b how far out,
// a how far up. UV2: x its size, y the wait (s) before it starts. On the crown UV
// is x round it, y up it; on the others the quad's corner.
// Lit by the sun as water is, brightest looked at against it. No ambient in this
// world: the sky's hemisphere comes in as emission.
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_disabled, world_vertex_coords, shadows_disabled;

global uniform vec3 zs_hemi_sky;
global uniform float zs_hemi_energy;

uniform float clock = 0.0;
uniform float gravity = 9.8;
uniform vec3 tint : source_color = vec3(0.86, 0.92, 0.96);
// The crown: how fast its rim is thrown (m/s) and out.
uniform float crown_up = 2.3;
uniform float crown_out = 0.65;
uniform float sky_fill = 1.3;
uniform float against_sun = 3.0;

varying flat float sort;
varying float fade;
varying flat float wobble;

// `shed` s after breaking, on the way out: where the fish was, and how fast.
vec3 fish_at(vec3 at, vec3 fling, float shed) {
	return at + fling * shed + vec3(0.0, -0.5 * gravity * shed * shed, 0.0);
}

void vertex() {
	float size = INSTANCE_CUSTOM.y;
	float going_in = INSTANCE_CUSTOM.z;
	float seed = INSTANCE_CUSTOM.w;
	vec3 at = MODEL_MATRIX[3].xyz;
	vec3 fling = MODEL_MATRIX[0].xyz;
	float t = clock - INSTANCE_CUSTOM.x - UV2.y;
	vec2 q = UV * 2.0 - 1.0;
	sort = COLOR.r;
	wobble = seed + COLOR.g;
	fade = 0.0;
	// Far off a splash is a few pixels: it stands a little taller than it is.
	float off = pow(max(distance(at, INV_VIEW_MATRIX[3].xyz) / 20.0, 1.0), 0.75);
	float grow = sqrt(size);
	vec3 place = at;
	vec3 moving = vec3(0.0, 1.0, 0.0);
	float half_size = 0.0;
	float streak = 1.0;
	VERTEX = at;
	NORMAL = vec3(0.0, 1.0, 0.0);
	if (t >= 0.0) {
		float heading = (COLOR.g + seed) * TAU;
		vec2 way = vec2(cos(heading), sin(heading));
		if (sort < 0.1) {
			// The crown: a wall thrown up and out, its rim on a real arc.
			float up = crown_up * grow * mix(0.75, 1.0, going_in);
			float life = 2.0 * up / gravity;
			if (t < life) {
				float round_way = UV.x * TAU;
				vec2 out_way = vec2(cos(round_way), sin(round_way));
				vec2 run = fling.xz / max(length(fling.xz), 0.1);
				// Thrown the fish's way, and unevenly.
				float lean = mix(1.0 + 0.5 * dot(out_way, run), 1.0 + 0.25 * dot(out_way, run), going_in);
				float lumpy = 1.0 + 0.3 * sin(round_way * 5.0 + seed * 40.0);
				float top = max(up * t - 0.5 * gravity * t * t, 0.0) * lean * lumpy * off;
				float r = (size * mix(0.09, 0.14, going_in) + crown_out * grow * t) * off + UV.y * top * 0.32;
				VERTEX = at + vec3(out_way.x * r, UV.y * top, out_way.y * r);
				NORMAL = normalize(vec3(out_way.x, 0.5, out_way.y));
				fade = 1.0 - smoothstep(0.3, 1.0, t / life);
			}
		} else if (sort < 0.35) {
			// A drop off the crown's rim.
			float live = 0.45 + 0.5 * COLOR.b;
			float up = (2.0 + 3.6 * COLOR.a) * grow * mix(0.75, 1.0, going_in);
			float out_speed = (0.5 + 2.0 * COLOR.b) * grow;
			vec3 v0 = vec3(way.x * out_speed, up, way.y * out_speed) + fling * vec3(0.12, 0.0, 0.12);
			vec3 p = v0 * t + vec3(0.0, -0.5 * gravity * t * t, 0.0);
			if (t < live && p.y > -0.03) {
				place = at + p;
				moving = v0 + vec3(0.0, -gravity * t, 0.0);
				half_size = UV2.x;
				fade = 1.0 - smoothstep(0.75, 1.0, t / live);
			}
		} else if (sort < 0.6) {
			// A drop shed along the fish's path: it leaves the body slower than the
			// fish, so they string out behind it and fall away.
			float shed = UV2.y;
			if (going_in < 0.5) {
				float keep = 0.55 + 0.35 * COLOR.a;
				vec3 from = fish_at(at, fling, shed);
				vec3 v0 = (fling + vec3(0.0, -gravity * shed, 0.0)) * keep + vec3(way.x, 0.0, way.y) * (0.2 + 0.7 * COLOR.b);
				vec3 p = from + v0 * t + vec3(0.0, -0.5 * gravity * t * t, 0.0);
				if (t < 1.1 && p.y > at.y - 0.03) {
					place = p;
					moving = v0 + vec3(0.0, -gravity * t, 0.0);
					half_size = UV2.x;
					fade = 1.0 - smoothstep(0.7, 1.1, t);
				}
			}
		} else if (sort < 0.85) {
			// The jet: the hole closing where it went in throws a stem up.
			if (going_in > 0.5) {
				float up = (1.4 + 2.2 * COLOR.a) * grow;
				float h = up * t - 0.5 * gravity * t * t;
				if (h > -0.02) {
					place = at + vec3(way.x * COLOR.b * 0.05, h, way.y * COLOR.b * 0.05);
					moving = vec3(0.0, up - gravity * t, 0.0);
					half_size = UV2.x * grow;
					fade = 0.9;
				}
			}
		} else {
			// A breath of mist off it, thin.
			float live = 0.8;
			float k = t / live;
			if (k < 1.0) {
				place = at + vec3(way.x * 0.4 * t, 0.12 + (0.5 + COLOR.a) * t * (1.0 - 0.4 * k), way.y * 0.4 * t) * vec3(1.0, grow, 1.0);
				half_size = UV2.x * grow * mix(0.6, 1.8, sqrt(k));
				fade = 0.16 * (1.0 - k) * (1.0 - k) * smoothstep(0.0, 0.1, k) * mix(0.6, 1.0, going_in);
			}
		}
	}
	if (sort >= 0.1 && fade > 0.0) {
		vec3 eye = INV_VIEW_MATRIX[3].xyz;
		vec3 look = normalize(place - eye);
		float far = distance(place, eye);
		if (sort > 0.85) {
			VERTEX = place + (INV_VIEW_MATRIX[0].xyz * q.x + INV_VIEW_MATRIX[1].xyz * q.y) * half_size;
		} else {
			// Drawn along their fall, and never under a pixel or so far off.
			half_size = max(half_size, far * 0.0011);
			float speed = length(moving);
			vec3 along = moving / max(speed, 0.01);
			vec3 across = cross(along, look);
			float wide = length(across);
			across = wide > 0.01 ? across / wide : INV_VIEW_MATRIX[0].xyz;
			streak = 1.0 + speed * 0.2 * wide;
			VERTEX = place + across * q.x * half_size + along * q.y * half_size * streak;
			NORMAL = -look;
		}
	}
}

void fragment() {
	vec3 sky = zs_hemi_sky * zs_hemi_energy / PI * sky_fill;
	if (sort < 0.1) {
		// Fingers at the rim, a sheet below, torn thinner as it climbs.
		float a = UV.x * TAU;
		float fingers = 0.66 + 0.34 * (sin(a * 13.0 + wobble * 9.0) * 0.5 + sin(a * 29.0 + wobble * 31.0) * 0.3 + sin(a * 61.0 + wobble * 17.0) * 0.2);
		float body = 1.0 - smoothstep(fingers - 0.16, fingers, UV.y);
		// Thin water: it tears into holes as it goes, more the older.
		float torn = sin(a * 37.0 + UV.y * 9.0 + wobble * 3.0) * sin(a * 83.0 - UV.y * 14.0 + wobble * 7.0) * 0.5 + 0.5;
		float hole = smoothstep(1.0 - fade, 1.0 - fade + 0.35, torn);
		ALPHA = clamp(body * hole * mix(0.62, 0.34, UV.y) * fade, 0.0, 1.0);
	} else {
		vec2 q = UV * 2.0 - 1.0;
		float r = length(q);
		float soft = sort > 0.85 ? 0.95 : 0.5;
		ALPHA = (1.0 - smoothstep(1.0 - soft, 1.0, r)) * fade;
	}
	ALBEDO = tint;
	EMISSION = tint * sky;
}

void light() {
	float round_way = clamp(dot(NORMAL, LIGHT) * 0.5 + 0.5, 0.0, 1.0);
	float through = pow(clamp(dot(LIGHT, -VIEW), 0.0, 1.0), 6.0);
	DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR / PI * (0.3 + 0.7 * round_way + through * against_sun);
}
