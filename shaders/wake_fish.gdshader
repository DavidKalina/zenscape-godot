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

varying float fin;
varying float eye;

void vertex() {
	float s = clamp(nose_z - VERTEX.z, 0.0, 0.9999) * 8.0;
	int i = int(s);
	vec3 a = spine[i];
	vec3 b = spine[i + 1];
	float k = s - float(i);
	vec3 joint = mix(a, b, k);
	float cs = cos(joint.z);
	float sn = sin(joint.z);
	float x = VERTEX.x;
	float y = VERTEX.y;
	fin = COLOR.r;
	eye = COLOR.g;
	// The paired fins swing about their roots.
	y += COLOR.b * flare * abs(x) * 0.8;
	x *= 1.0 - 0.25 * COLOR.b * max(-flare, 0.0);
	VERTEX = vec3(joint.x + x * cs, y, joint.y + x * sn);
	vec3 n = NORMAL;
	NORMAL = vec3(n.x * cs - n.z * sn, n.y, n.x * sn + n.z * cs);
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
	vec3 hemi = mix(zs_hemi_ground * bounce, zs_hemi_sky, world_n.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	vec3 mirror_way = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).xyz;
	vec3 sky = mix(zs_hemi_ground * bounce, zs_hemi_sky, mirror_way.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float sun_in_it = pow(max(dot(normalize(mirror_way), zs_key_direction), 0.0), flash_tight);
	float sunward = clamp(dot(world_n, zs_key_direction), 0.0, 1.0);
	float sky_luma = dot(zs_hemi_sky, vec3(0.2126, 0.7152, 0.0722));
	vec3 lift = mix(zs_hemi_sky, vec3(sky_luma), 0.7) * zs_hemi_energy * shade_lift * mix(0.1, 1.0, zs_daylight) * mix(1.0, 0.3, sunward);
	EMISSION = base * (hemi * fill + lift) + mix(base, vec3(0.85), 0.6) * flank_share * (sky * mirror + vec3(sun_in_it * flash * zs_daylight));
}
