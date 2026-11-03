shader_type spatial;
// The leaping fish (scripts/endless/wake_fish.gd): assets/models/fish/hero_fish.glb,
// a metre nose to tail, nose along +Z. The script flies it and bends it: `spine`
// is the body's curve this frame, each section of the mesh set on it and turned
// with it, so it flexes through its length and doesn't shear. Lit as the world
// is: no ambient, the sky's hemisphere added as emission
// (shaders/folk_surface.gdshaderinc).
// The skin's channels (art/blender/fish/fish_build.py): R the dark of the back,
// G the spots, B the lines, A the scales; the tints say what fish it is.
// COLOR: R a fin, G an eye, B a paired fin, root to tip.
render_mode diffuse_lambert, specular_schlick_ggx, cull_disabled;

global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
global uniform vec3 zs_key_direction;
global uniform float zs_daylight;

uniform sampler2D skin : hint_default_black, filter_linear_mipmap_anisotropic, repeat_disable;
// Nine joints nose to tail, a metre of body shared evenly: x and z in the mesh's
// metres, and how far the section there is turned (rad).
uniform vec3 spine[9];
uniform float nose_z = 0.42;
// The paired fins held out or laid back.
uniform float flare = 0.0;
uniform vec3 back_tint : source_color = vec3(0.12, 0.17, 0.16);
uniform vec3 flank_tint : source_color = vec3(0.62, 0.64, 0.6);
uniform vec3 belly_tint : source_color = vec3(0.9, 0.9, 0.86);
uniform vec3 spot_tint : source_color = vec3(0.04, 0.04, 0.05);
uniform vec3 band_tint : source_color = vec3(0.7, 0.3, 0.3);
uniform vec3 fin_tint : source_color = vec3(0.25, 0.25, 0.25);
uniform float spot_share = 0.8;
uniform float band_share = 0.0;
// The sky's fill and the bounce off the water under it.
uniform float fill = 2.2;
uniform float bounce = 3.0;
// The world's fill is a twentieth of the sun: a near-neutral lift off the sky's
// own light, strongest away from the sun, as the plane has
// (assets/models/hero_plane/hero_surface.gdshader).
uniform float shade_lift = 3.2;
// The flank is a mirror of sorts: the sky in it, and for the instant it faces
// right, the sun, all along the flank.
uniform float mirror = 0.9;
uniform float flash = 3.0;
uniform float flash_tight = 45.0;
// Under the water (the swimmer, scripts/endless/swim_fish.gd): how much the
// water over it takes (0 for a leap), where its top is (world y), and what it
// turns the body to, more the deeper (per m).
uniform float under = 0.0;
uniform float surface_y = 0.0;
uniform vec3 under_tint : source_color = vec3(0.04, 0.09, 0.11);
uniform float under_fade = 2.5;
// The sky's fill and bounce under the surface, a share of what's above it: the
// fin that stands out keeps the air's.
uniform float under_light = 1.0;
// The dorsal grown taller (mesh metres added to its front tip, the rest of it in
// step and raked back with it), so the swimmer's stands out of the water.
uniform float dorsal_lift = 0.0;
// How much of the tail's upper lobe's height is taken off (0 for a leap).
uniform float tail_low = 0.0;
// The sky's sheen off a wet fin in the air (0 for a leap: its fins are small).
uniform float fin_wet = 0.0;

varying float fin;
varying float eye;
varying float world_y;

void vertex() {
	float x = VERTEX.x;
	float y = VERTEX.y;
	float z = VERTEX.z;
	// The dorsal: the fin over the back ahead of the adipose (art/blender/fish/
	// fish_build.py: its tip heights fall 0.085, 0.078, 0.052, 0.022 root to rear,
	// UV.x root to rear and UV.y root to tip).
	// Grown, its rear stands nearly as tall as its front, so what's out of the
	// water has some breadth seen from behind.
	if (dorsal_lift > 0.0 && COLOR.r > 0.5 && y > 0.0 && z > -0.18) {
		float rear = UV.x * 3.0;
		float shape = rear < 1.0 ? mix(1.0, 0.96, rear) : (rear < 2.0 ? mix(0.96, 0.82, rear - 1.0) : mix(0.82, 0.5, rear - 2.0));
		float up = UV.y * shape * dorsal_lift;
		y += up;
		z -= up * (0.25 + 0.6 * UV.x);
	}
	// The tail's upper lobe folded lower (the swimmer's, under a swell that
	// otherwise lays it bare in the troughs).
	if (COLOR.r > 0.5 && y > 0.0 && z < -0.36) y *= 1.0 - tail_low;
	float s = clamp(nose_z - z, 0.0, 0.9999) * 8.0;
	int i = int(s);
	vec3 a = spine[i];
	vec3 b = spine[i + 1];
	float k = s - float(i);
	vec3 joint = mix(a, b, k);
	float cs = cos(joint.z);
	float sn = sin(joint.z);
	fin = COLOR.r;
	eye = COLOR.g;
	// The paired fins swing about their roots.
	y += COLOR.b * flare * abs(x) * 0.8;
	x *= 1.0 - 0.25 * COLOR.b * max(-flare, 0.0);
	VERTEX = vec3(joint.x + x * cs, y, joint.y + x * sn);
	vec3 n = NORMAL;
	NORMAL = vec3(n.x * cs - n.z * sn, n.y, n.x * sn + n.z * cs);
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 base;
	float flank_share = 0.0;
	float wet_rough = 0.3;
	if (eye > 0.5) {
		// A black pupil in a pale ring.
		float r = length(UV - vec2(0.5)) * 2.0;
		base = mix(vec3(0.01), vec3(0.6, 0.5, 0.3), smoothstep(0.55, 0.7, r));
		wet_rough = 0.12;
	} else if (fin > 0.5) {
		// Rays, running out from the root, darker to the edge.
		float ray = 0.82 + 0.18 * sin(UV.x * 44.0);
		base = mix(flank_tint * 0.5, fin_tint, smoothstep(0.1, 0.8, 1.0 - UV.y)) * ray;
		wet_rough = 0.42;
	} else {
		vec4 m = texture(skin, UV);
		float round_way = 1.0 - UV.y;
		float belly = 1.0 - smoothstep(0.14, 0.46, round_way);
		base = mix(flank_tint, belly_tint, belly);
		// The band along the flank.
		base = mix(base, band_tint, band_share * smoothstep(0.08, 0.0, abs(round_way - 0.5)) * smoothstep(0.08, 0.2, UV.x));
		base = mix(base, back_tint, m.r);
		base = mix(base, spot_tint, m.g * spot_share);
		base *= 1.0 - 0.75 * m.b;
		base *= 0.86 + 0.28 * m.a;
		flank_share = (1.0 - m.r) * (1.0 - m.g * spot_share) * (0.75 + 0.25 * m.a);
		wet_rough = mix(0.34, 0.24, m.a);
	}
	ALBEDO = base;
	ROUGHNESS = wet_rough;
	METALLIC = 0.15 * flank_share;
	SPECULAR = 0.65;
	float lit = mix(1.0, under_light, under * smoothstep(0.0, 0.08, surface_y - world_y));
	float fill_here = fill * lit;
	float bounce_here = bounce * lit;
	vec3 hemi = mix(zs_hemi_ground * bounce_here, zs_hemi_sky, world_n.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	vec3 mirror_way = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).xyz;
	vec3 sky = mix(zs_hemi_ground * bounce_here, zs_hemi_sky, mirror_way.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float sun_in_it = pow(max(dot(normalize(mirror_way), zs_key_direction), 0.0), flash_tight);
	float sunward = clamp(dot(world_n, zs_key_direction), 0.0, 1.0);
	float sky_luma = dot(zs_hemi_sky, vec3(0.2126, 0.7152, 0.0722));
	vec3 lift = mix(zs_hemi_sky, vec3(sky_luma), 0.7) * zs_hemi_energy * shade_lift * mix(0.1, 1.0, zs_daylight) * mix(1.0, 0.3, sunward);
	EMISSION = base * (hemi * fill_here + lift) + mix(base, vec3(0.85), 0.6) * flank_share * (sky * mirror + vec3(sun_in_it * flash * zs_daylight));
	// A wet fin or back out of the water: the sky off it, most where it's seen edge on.
	if (fin_wet > 0.0) {
		float edge_on = 1.0 - abs(dot(NORMAL, VIEW));
		EMISSION += sky * fin_wet * (fin > 0.5 ? 1.0 : 0.8) * (0.08 + 0.92 * edge_on * edge_on * edge_on);
	}
	// Under the water its colours go to the water's, and the sun's shine with them.
	if (under > 0.0) {
		// Most of it at once under the surface (the sun and sky come through it
		// dim and blue), the rest with depth.
		float d = surface_y - world_y;
		float t = under * smoothstep(0.0, 0.08, d) * (0.75 + 0.25 * (1.0 - exp(-max(d, 0.0) * under_fade)));
		// The sun reaches it dimmed too, or its sunward flank lights up white.
		ALBEDO = mix(base, under_tint, t) * (1.0 - 0.6 * t);
		// The sun's glint off a wet flank is the surface's under water, not its.
		SPECULAR = 0.65 * (1.0 - smoothstep(0.0, 0.5, t));
		ROUGHNESS = mix(wet_rough, 1.0, t);
		METALLIC *= 1.0 - t;
		EMISSION = mix(EMISSION, under_tint * hemi * fill_here, t);
	}
}
