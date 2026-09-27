shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_back;
// A held ball of the ponds' own water (scripts/water_ball.gd), drawn as a
// volume. The ponds' colours (the depth ramp in GardenView `sample_ponds`
// times zs_palette_water), lit as the pond is (key light and hemisphere,
// shaders/reference_lake_lighting.gdshaderinc), with the pond's fresnel, sky
// reflection and sun glint.
// Inside, a ray refracted at the surface is marched through the water against
// the depth buffer: it stops on the fish (or the ground, once the ball
// squashes), so what is near the front shows clear and what is deep takes the
// ponds' absorption. Rays that get through refract out again, so the ball
// lenses the world behind it. A vortex spins the water: spiral veils of fine
// bubbles wind round and climb, bubbles rise and drift into the core, an air
// funnel twists down from a whirlpool dimple on top, and the surface carries
// swirling foam and ripple rings (from the script's `ripples`, and a few of
// its own).
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
#include "res://shaders/pool_caustics.gdshaderinc"
global uniform vec3 zs_palette_water;
uniform sampler2D ball_screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D ball_depth : hint_depth_texture, filter_nearest, repeat_disable;
// Ball radius in metres (the mesh is a unit sphere scaled to it).
uniform float radius = 1.0;
// Surface wobble height, as a share of the radius; the script raises it on
// a jolt (a hop, a catch-up, the impact) and lets it ring down.
uniform float wobble = 0.03;
// The vortex's turned angle (radians, integrated by the script so a change of
// pace never jumps) and how hard it is spinning (0..1).
uniform float swirl = 0.0;
uniform float churn = 0.5;
// Foam on the surface (0..1): a base froth, more when shaken.
uniform float foam = 0.3;
// Whirlpool dimple and air funnel (0..1), grown with the ball.
uniform float funnel = 1.0;
// How far the surface bends light: 0 sees straight through, 1 is water.
uniform float lens = 0.35;
// 0 while held; rises to 1 as the ball bursts, thinning it to foam.
uniform float burst = 0.0;
// 1 once it has hit the ground: its bubbles have gone with the splash.
uniform float landed = 0.0;
// Seconds the ball has existed (TIME keeps running when paused).
uniform float age = 0.0;
// Ripple rings: object-space direction on the ball, and the age they began.
uniform vec4 ripples[10];
// Bubbles rising through the vortex: object-space centre and radius (the
// script moves them; radius 0 is none).
uniform vec4 bubbles[18];
varying vec3 local_position;
varying vec3 world_position;

const int STEPS = 18;
const float IOR = 1.333;
const vec3 SHALLOW = vec3(0.19, 0.42, 0.33);
const vec3 DEEP = vec3(0.018, 0.10, 0.11);
const vec3 FOAM = vec3(0.86, 0.94, 0.93);

float hash1(float n) { return fract(sin(n * 12.9898) * 43758.5453); }
float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}
float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.03 + 7.1) * 0.3 + vnoise(p * 4.1 + 3.7) * 0.15;
}
vec3 spin_y(vec3 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(c * p.x - s * p.z, p.y, s * p.x + c * p.z);
}

// The surface's own shape: a slow wobble and the whirlpool dimple on top.
float surface_height(vec3 n) {
	float t = age;
	float shape = sin(n.x * 3.1 + t * 2.3) * sin(n.y * 2.7 - t * 1.9) + 0.6 * sin(n.z * 3.7 + t * 2.9 + n.y * 1.5);
	float polar = acos(clamp(n.y, -1.0, 1.0));
	float dimple = exp(-polar * polar / 0.03) * 0.045 * funnel;
	// A lip of water climbs round the dimple as it spins.
	float lip = exp(-pow((polar - 0.36) / 0.12, 2.0)) * 0.008 * funnel;
	return shape * wobble - dimple + lip;
}

// Ripple rings running out over the surface from `source` since `since` s.
float ring_slope(vec3 n, vec3 source, float since) {
	if (since < 0.0 || since > 1.6) return 0.0;
	float along = acos(clamp(dot(n, source), -1.0, 1.0));
	float front = since * 1.1;
	float packet = exp(-pow((along - front) / 0.16, 2.0));
	return cos((along - front) * 38.0) * packet * exp(-since * 2.4) * smoothstep(0.0, 0.12, since);
}

// Surface normal (object space) with its ripples and the swirl's chop.
vec3 surface_normal(vec3 n) {
	vec3 tangent = normalize(cross(abs(n.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0), n));
	vec3 bitangent = cross(n, tangent);
	float e = 0.02;
	float h0 = surface_height(n);
	float hx = surface_height(normalize(n + tangent * e)) - h0;
	float hy = surface_height(normalize(n + bitangent * e)) - h0;
	vec3 normal = normalize(n - (tangent * hx + bitangent * hy) / e);
	// Fine chop carried round by the swirl.
	vec3 q = spin_y(n, -swirl * 0.8) * vec3(9.0, 14.0, 9.0);
	float c0 = vnoise(q + vec3(0.0, age * 0.9, 0.0));
	float cx = vnoise(q + vec3(0.35, age * 0.9, 0.0)) - c0;
	float cy = vnoise(q + vec3(0.0, age * 0.9 + 0.35, 0.0)) - c0;
	normal = normalize(normal - (tangent * cx + bitangent * cy) * (0.25 + churn * 0.35));
	// Ring ripples: the script's (droplets arriving, fish nudging) and a few of
	// the ball's own, each pushing the normal out along its front.
	for (int i = 0; i < 10; i++) {
		vec3 source = ripples[i].xyz;
		if (dot(source, source) < 0.5) continue;
		float s = ring_slope(n, source, age - ripples[i].w);
		vec3 out_dir = normalize(n * dot(n, source) - source + 1e-4);
		normal = normalize(normal + out_dir * s * 0.28);
	}
	for (int i = 0; i < 3; i++) {
		float period = 1.7 + float(i) * 0.37;
		float cycle = floor(age / period + float(i) * 0.33);
		float since = (age / period + float(i) * 0.33 - cycle) * period;
		float a = hash1(cycle * 3.1 + float(i)) * 6.2832;
		float y = mix(-0.2, 0.85, hash1(cycle * 7.7 + float(i) * 1.3));
		vec3 source = normalize(vec3(cos(a) * sqrt(1.0 - y * y), y, sin(a) * sqrt(1.0 - y * y)));
		float s = ring_slope(n, source, since);
		vec3 out_dir = normalize(n * dot(n, source) - source + 1e-4);
		normal = normalize(normal + out_dir * s * 0.18);
	}
	return normal;
}

// Surface foam: froth wound into the dimple, thin streaks the swirl drags
// down and round from it, and lace everywhere as the ball is shaken.
float surface_foam(vec3 n) {
	float polar = acos(clamp(n.y, -1.0, 1.0));
	float around = atan(n.z, n.x);
	vec3 q = spin_y(n, -swirl * 1.1);
	float breakup = fbm(q * vec3(4.0, 7.0, 4.0) + vec3(0.0, age * 0.2, 0.0));
	float fine = vnoise(q * vec3(16.0, 28.0, 16.0) + vec3(0.0, age * 0.6, 0.0));
	float wind = polar * 22.0 + around * 2.0 - swirl * 1.3 + breakup * 3.0;
	float lines = pow(0.5 + 0.5 * sin(wind), 16.0) * smoothstep(1.3, 0.45, polar);
	float streaks = lines * smoothstep(0.45, 0.75, breakup) * smoothstep(0.3, 0.7, fine) * (0.4 + foam) * 0.8;
	float arms = sin(around * 3.0 + log(max(polar, 0.03)) * 4.5 - swirl * 1.6);
	float whirl = smoothstep(0.3, 1.0, arms) * smoothstep(0.75, 0.2, polar) * smoothstep(0.06, 0.16, polar);
	float froth = (whirl + exp(-pow((polar - 0.26) / 0.08, 2.0)) * 0.7) * funnel * smoothstep(0.3, 0.65, breakup);
	float lace = smoothstep(0.66, 0.8, breakup) * foam * 0.6;
	return clamp(max(max(froth, streaks), lace), 0.0, 1.0);
}

// Swirling veils of fine bubbles inside: spiral arms that wind round the axis
// and climb (a barber pole), broken up by noise turning at their own pace.
float veil_density(vec3 p) {
	float r = length(p.xz);
	// sin(3θ + φ) from the point itself, without an atan: cos 3θ and sin 3θ
	// are cubics in cos θ and sin θ.
	vec2 unit = p.xz / max(r, 1e-4);
	float c3 = unit.x * (4.0 * unit.x * unit.x - 3.0);
	float s3 = unit.y * (3.0 - 4.0 * unit.y * unit.y);
	float phase = -swirl + r * 7.0 + p.y * 4.0;
	float arms = s3 * cos(phase) + c3 * sin(phase);
	float line = pow(0.5 + 0.5 * arms, 12.0);
	if (line < 0.02) return 0.0;
	float breakup = vnoise(spin_y(p, -swirl * (0.9 + (1.0 - r) * 0.6)) * vec3(3.5, 6.0, 3.5));
	float shell = smoothstep(0.08, 0.3, r) * (1.0 - smoothstep(0.8, 0.98, length(p)));
	return line * smoothstep(0.35, 0.8, breakup) * shell;
}

// World-space position of the depth buffer at `uv`, as a view-space z.
float scene_view_z(vec2 uv, mat4 inv_projection) {
	float depth = textureLod(ball_depth, uv, 0.0).r;
	vec4 view = inv_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return view.z / view.w;
}

vec2 to_screen(vec3 world, mat4 view_matrix, mat4 projection) {
	vec4 clip = projection * (view_matrix * vec4(world, 1.0));
	return clip.xy / clip.w * 0.5 + 0.5;
}

// Far intersection of the ray `origin + dir t` with the unit sphere.
float sphere_exit(vec3 origin, vec3 dir) {
	float a = dot(dir, dir);
	float b = dot(origin, dir);
	float c = dot(origin, origin) - 1.0;
	float h = b * b - a * c;
	if (h < 0.0) return 0.0;
	return max((-b + sqrt(h)) / a, 0.0);
}

// Near hit of the ray with a small sphere; -1 when missed. `edge` is how far
// off centre the ray passes, 0 through the middle, 1 grazing.
float bubble_hit(vec3 origin, vec3 dir, vec3 center, float size, out float edge) {
	vec3 o = origin - center;
	float a = dot(dir, dir);
	float b = dot(o, dir);
	float c = dot(o, o) - size * size;
	float h = b * b - a * c;
	edge = 1.0;
	if (h < 0.0) return -1.0;
	float closest = length(o - dir * (b / a));
	edge = closest / size;
	return (-b - sqrt(h)) / a;
}

void vertex() {
	local_position = VERTEX;
	vec3 n = normalize(VERTEX);
	VERTEX += n * surface_height(n);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	mat4 to_ball = inverse(MODEL_MATRIX);
	mat3 normal_to_world = transpose(mat3(to_ball));
	vec3 n = normalize(local_position);
	vec3 normal_local = surface_normal(n);
	vec3 normal = normalize(normal_to_world * normal_local);
	vec3 eye = normalize(CAMERA_POSITION_WORLD - world_position);
	float facing = max(dot(eye, normal), 0.0);
	float fresnel = 0.02 + 0.98 * pow(1.0 - facing, 5.0);
	fresnel = mix(fresnel, 0.02 + 0.70 * pow(1.0 - facing, 5.0), 0.5);

	// Light, as the pond takes it: the key light and the hemisphere.
	vec3 key = zs_key_irradiance / PI;
	vec3 sky_light = zs_hemi_sky * zs_hemi_energy / PI;
	vec3 ground_light = zs_hemi_ground * zs_hemi_energy / PI;
	vec3 sun_local = normalize(mat3(to_ball) * zs_key_direction + vec3(0.0, 1e-4, 0.0));

	// Into the water: refracted at the surface, marched against the depth buffer.
	vec3 ray = normalize(mix(-eye, refract(-eye, normal, 1.0 / IOR), lens));
	vec3 origin_local = (to_ball * vec4(world_position, 1.0)).xyz;
	vec3 ray_local = mat3(to_ball) * ray;
	float exit = sphere_exit(origin_local, ray_local);
	float jitter = hash3(vec3(FRAGCOORD.xy, fract(age * 7.0) * 61.0));
	float dt = exit / float(STEPS);
	// Along the ray the view and clip positions are linear in t.
	vec4 view_start = VIEW_MATRIX * vec4(world_position, 1.0);
	vec4 view_step = VIEW_MATRIX * vec4(ray, 0.0);
	vec4 clip_start = PROJECTION_MATRIX * view_start;
	vec4 clip_step = PROJECTION_MATRIX * view_step;
	vec4 depth_z = vec4(INV_PROJECTION_MATRIX[0].z, INV_PROJECTION_MATRIX[1].z, INV_PROJECTION_MATRIX[2].z, INV_PROJECTION_MATRIX[3].z);
	vec4 depth_w = vec4(INV_PROJECTION_MATRIX[0].w, INV_PROJECTION_MATRIX[1].w, INV_PROJECTION_MATRIX[2].w, INV_PROJECTION_MATRIX[3].w);
	float thick = max(0.3, dt * 1.5);
	vec3 transmit = vec3(1.0);
	vec3 scattered = vec3(0.0);
	vec3 sigma = vec3(1.1, 0.42, 0.3);
	float travelled = exit;
	bool stopped = false;
	vec2 hit_uv = SCREEN_UV;
	vec3 shallow = SHALLOW * zs_palette_water;
	vec3 deep = DEEP * zs_palette_water;
	for (int i = 0; i < STEPS; i++) {
		float t = (float(i) + jitter) * dt;
		vec4 clip = clip_start + clip_step * t;
		vec2 uv = clip.xy / clip.w * 0.5 + 0.5;
		vec4 ndc = vec4(uv * 2.0 - 1.0, textureLod(ball_depth, uv, 0.0).r, 1.0);
		float solid = dot(depth_z, ndc) / dot(depth_w, ndc);
		float here = view_start.z + view_step.z * t;
		// Only a ray that passes into something counts, not one behind it (a
		// fish is a thin thing in the depth buffer).
		if (here < solid - 0.01 && here > solid - thick) {
			// Behind something solid inside the ball (a fish): step back to its edge.
			float lo = max(t - dt, 0.0);
			float hi = t;
			for (int k = 0; k < 4; k++) {
				float mid = (lo + hi) * 0.5;
				vec4 c = clip_start + clip_step * mid;
				vec2 u = c.xy / c.w * 0.5 + 0.5;
				vec4 n4 = vec4(u * 2.0 - 1.0, textureLod(ball_depth, u, 0.0).r, 1.0);
				float z = dot(depth_z, n4) / dot(depth_w, n4);
				float v = view_start.z + view_step.z * mid;
				if (v < z - 0.01 && v > z - thick) hi = mid; else lo = mid;
			}
			travelled = hi;
			vec4 c = clip_start + clip_step * hi;
			hit_uv = c.xy / c.w * 0.5 + 0.5;
			stopped = true;
			break;
		}
		vec3 p = origin_local + ray_local * t;
		// Sunlight reaching this point through the water above it.
		float pl = dot(p, sun_local);
		float to_sun = -pl + sqrt(max(pl * pl - dot(p, p) + 1.0, 0.0));
		float lit = exp(-to_sun * radius * 0.9);
		// Shafts: the wobbling surface focuses the sun into moving ribbons.
		vec3 across = p - sun_local * pl;
		float shaft = pow(0.5 + 0.5 * sin(dot(across, vec3(7.0, 3.0, 5.0)) + age * 0.9), 6.0);
		float veil = veil_density(p);
		vec3 light = mix(ground_light, sky_light, p.y * 0.5 + 0.5) + key * lit * (0.3 + shaft * 0.45);
		vec3 step_transmit = exp(-(sigma + veil * 2.5) * dt);
		vec3 water = mix(deep, shallow, lit * 0.7 + 0.3) * light;
		vec3 fleck = mix(shallow, FOAM, 0.7) * light * 1.2;
		vec3 source = mix(water, fleck, veil / (veil + 0.5 + 1e-4));
		scattered += transmit * (1.0 - step_transmit) * source;
		transmit *= step_transmit;
	}

	vec3 behind;
	if (stopped) {
		// A fish in the ball: sunlight through the wobbling surface plays over it.
		behind = textureLod(ball_screen, hit_uv, 0.0).rgb;
		vec3 p = origin_local + ray_local * travelled;
		vec3 across = p - sun_local * dot(p, sun_local);
		float caustic = zs_pool_caustics(vec2(dot(across, vec3(1.0, 0.0, 0.3)), dot(across, vec3(0.2, 0.7, 1.0))) * radius * 1.6, age * 2.2);
		behind *= 1.15 + caustic * 1.3 * zs_daylight * zs_celestial_clear;
	} else {
		// Out the far side: refract again and look at what lies beyond.
		vec3 exit_local = origin_local + ray_local * exit;
		vec3 exit_normal = normalize(normal_to_world * exit_local);
		vec3 out_ray = refract(ray, -exit_normal, IOR);
		if (dot(out_ray, out_ray) < 0.5) out_ray = reflect(ray, -exit_normal);
		out_ray = normalize(mix(ray, out_ray, lens));
		vec3 exit_world = world_position + ray * exit;
		vec2 exit_uv = to_screen(exit_world, VIEW_MATRIX, PROJECTION_MATRIX);
		vec4 exit_view = VIEW_MATRIX * vec4(exit_world, 1.0);
		float beyond = clamp(exit_view.z - scene_view_z(clamp(exit_uv, 0.0, 1.0), INV_PROJECTION_MATRIX), 0.5, 40.0);
		vec2 far_uv = clamp(to_screen(exit_world + out_ray * beyond, VIEW_MATRIX, PROJECTION_MATRIX), vec2(0.002), vec2(0.998));
		behind = textureLod(ball_screen, far_uv, 0.0).rgb;
		// Landing on something inside the ball (a fish, seen a second time) is
		// not what lies beyond: the water's own colour there instead.
		if (scene_view_z(far_uv, INV_PROJECTION_MATRIX) > exit_view.z - 0.05) {
			behind = mix(deep, shallow, 0.4) * (mix(ground_light, sky_light, 0.6) + key * 0.3);
		}
	}
	vec3 inside = behind * transmit + scattered;

	// Bubbles rising through the vortex, drifting in toward the core.
	float bubble_light = dot(sky_light + key * 0.6, vec3(0.3, 0.59, 0.11));
	for (int i = 0; i < 18; i++) {
		vec3 center = bubbles[i].xyz;
		float size = bubbles[i].w * (1.0 - landed);
		if (size <= 0.0) continue;
		float edge;
		float hit = bubble_hit(origin_local, ray_local, center, size, edge);
		if (hit > 0.0 && hit < travelled) {
			// An air bubble: a bright rim where the water reflects wholly,
			// a clear middle, and a pinpoint of the sun.
			vec3 bubble_normal = normalize(origin_local + ray_local * hit - center);
			float ring = smoothstep(0.5, 0.95, edge) * 0.85 + 0.1;
			float spark = pow(max(dot(reflect(normalize(ray_local), bubble_normal), sun_local), 0.0), 30.0);
			vec3 through = mix(vec3(1.0), exp(-sigma * hit), 0.5);
			inside = mix(inside, vec3(0.92, 0.98, 1.0) * bubble_light * 3.2 * through, ring * 0.75) + spark * vec3(1.0, 0.95, 0.85) * bubble_light * 4.0 * through;
		}
	}

	// The air funnel: a twisting silver tube from the dimple down the axis.
	if (funnel > 0.01) {
		for (int k = 0; k < 10; k++) {
			float t = travelled * (float(k) + 0.5) / 10.0;
			vec3 p = origin_local + ray_local * t;
			float depth = 1.0 - p.y;
			float width = 0.05 * funnel * smoothstep(1.1, 0.05, depth) * (0.75 + 0.25 * sin(p.y * 9.0 - swirl * 3.0));
			vec2 wander = vec2(cos(p.y * 5.0 - swirl * 2.0), sin(p.y * 5.0 - swirl * 2.0)) * 0.035 * depth;
			float d = length(p.xz - wander);
			if (d < width) {
				float twist = 0.5 + 0.5 * sin(atan(p.z - wander.y, p.x - wander.x) * 2.0 + p.y * 14.0 - swirl * 4.0);
				vec3 silver = mix(vec3(0.78, 0.9, 0.9), vec3(1.0), twist * 0.7) * bubble_light * 2.4;
				inside = mix(inside, silver * mix(vec3(1.0), exp(-sigma * t), 0.4), (0.7 * smoothstep(width, width * 0.3, d) + 0.1) * smoothstep(1.1, 0.6, depth));
				break;
			}
		}
	}

	// The surface: sky and ground in the reflection, the sun's glint, foam.
	vec3 reflected = reflect(-eye, normal);
	vec3 sky = scene_linear_for_display(clamp(zsSkyGradient(vec3(reflected.x, abs(reflected.y), reflected.z)), vec3(0.0), vec3(0.98)));
	vec3 ground = (vec3(0.28, 0.36, 0.22) * (key * max(zs_key_direction.y, 0.0) + sky_light)) * 1.2;
	vec3 reflection = mix(sky, ground, smoothstep(0.05, -0.25, reflected.y));
	vec3 color = mix(inside, reflection, fresnel);
	vec3 half_vector = normalize(zs_key_direction + eye);
	float nh = max(dot(normal, half_vector), 0.0);
	float glint = pow(nh, 900.0) * 3.5 + pow(nh, 90.0) * 0.18;
	color += zs_key_irradiance / PI * glint * zs_celestial_clear;
	float froth = surface_foam(n);
	// Bursting, it breaks into foam from the rim in.
	froth = max(froth, burst * smoothstep(0.35, 1.0, 1.0 - facing + burst * 0.4) * 0.7);
	vec3 foam_light = mix(ground_light, sky_light, normal.y * 0.5 + 0.5) + key * max(dot(normal, zs_key_direction), 0.0);
	color = mix(color, FOAM * foam_light * 1.1, froth * 0.9);
	ALBEDO = color;
	ALPHA = clamp(1.0 - burst * (1.4 - burst * 0.4), 0.0, 1.0);
}
