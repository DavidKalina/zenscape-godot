shader_type spatial;
// Written by art/blender/ship/ship_build.py. Lit as the world is: no ambient,
// the sky's hemisphere added as emission (shaders/folk_surface.gdshaderinc),
// so a stock material would go black out of the sun.
render_mode diffuse_lambert, specular_schlick_ggx;
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float fill = 1.6;
uniform float rim = 0.3;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
global uniform vec3 zs_sun_direction;
global uniform vec3 zs_sun_hue;
uniform float normal_depth = 0.0;
uniform float roughness_value = 0.9;
uniform float metallic_value = 0.0;
uniform float fill_in = 1.5;
uniform float lamp_power = 8.0;
uniform float slat_power = 6.0;
uniform float glint = 0.0;
uniform float inside_x = 99.0;
uniform float calm = 0.0;
uniform float seam = 0.0;
uniform float liner = 1.0;
const float KEEL = -5.8;
const float STRAKE = 1.2;
const float GLOOM = 28.0;
const float LAMP_X = 9.4;
const float LAMP_Y = 11.8;
const float PITCH = 16.0;
const float LAST = 48.5;
const float PORT_W = 3.0;
const float PORT_LO = 6.2;
const float PORT_HI = 9.8;
const float PORT_X = 13.94;
const float PORT_FIRST = -40.0;
const float PORT_LAST = 40.0;
const vec3 FLAME = vec3(1.0, 0.58, 0.28);
varying vec3 at;
varying vec3 way;
varying flat vec3 sun;
varying flat float eyes;
void vertex() {
	at = VERTEX;
	way = NORMAL;
	mat3 back = transpose(mat3(MODEL_MATRIX));
	sun = normalize(back * zs_sun_direction);
	// An eye out in the day sees a hold as black; it opens up as it comes in.
	vec3 eye = abs(back * (CAMERA_POSITION_WORLD - MODEL_MATRIX[3].xyz));
	eyes = 1.0 - smoothstep(4.0, 40.0, max(eye.z - 55.0, max(eye.x - 9.0, 0.0)));
}
// The lantern at bay `z` on side `s`, here: wrapped so ribs turn into shade, not off.
float lantern(vec3 n, float z, float s) {
	if (abs(z) < 1.0 || abs(z) > LAST) return 0.0;
	vec3 l = vec3(s * LAMP_X, LAMP_Y, z) - at;
	float d2 = dot(l, l);
	float near = max(1.0 - d2 / 177.1875, 0.0);
	float a = dot(n, l) / sqrt(d2);
	float beat = 0.9 + 0.1 * sin(TIME * (7.0 + fract(z * 0.37 + s) * 5.0) + z);
	return (max(a, 0.0) * 0.8 + 0.2) * near * near * beat;
}
void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	base = mix(base, vec3(0.5, 0.41, 0.31), calm);
	// A strake's seam along the liner: the tile's rows don't fall on them.
	if (abs(way.x) > 0.6) base *= liner * (1.0 - seam * smoothstep(0.42, 0.47, abs(fract((at.y - KEEL) / STRAKE) - 0.5)));
	base *= COLOR.rgb;
	ALBEDO = base;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	if (normal_depth > 0.0) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
	}
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, n.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	vec3 outside = base * hemi * fill + base * zs_hemi_sky * zs_hemi_energy * edge * rim;
	float inside = 1.0 - smoothstep(inside_x, inside_x + 0.4, abs(at.x));
	if (inside > 0.0) {
		vec3 nl = normalize(way);
		float d = length(VERTEX);
		float gloom = 1.0 / (1.0 + d * d / (GLOOM * GLOOM));
		// The two bays either side of here, a lantern each side of the deck.
		float b = floor(at.z / PITCH) * PITCH;
		float s = at.x < 0.0 ? -1.0 : 1.0;
		float lamps = lantern(nl, b, s) + lantern(nl, b + PITCH, s)
			+ 0.55 * (lantern(nl, b, -s) + lantern(nl, b + PITCH, -s));
		// The sun, back along its line to the wall on its side, through a port?
		float slat = 0.0;
		if (sun.y > 0.03 && abs(sun.x) > 0.05) {
			float t = (sign(sun.x) * PORT_X - at.x) / sun.x;
			vec3 h = at + sun * t;
			float pz = clamp(round((h.z + PITCH * 0.5) / PITCH) * PITCH - PITCH * 0.5, PORT_FIRST, PORT_LAST);
			vec2 q = vec2(abs(h.z - pz) - PORT_W * 0.5, max(PORT_LO - h.y, h.y - PORT_HI));
			float through = smoothstep(0.1, -0.1, q.x) * smoothstep(0.1, -0.1, q.y);
			float barrel = smoothstep(0.5, 0.75, length(vec2(h.z - pz, h.y - 8.0)));
			slat = t > 0.0 ? through * barrel * max(dot(nl, sun), 0.0) : 0.0;
		}
		vec3 sunlit = zs_sun_hue * slat * slat_power;
		// The fill falls off with the eye's distance, so the hold keeps its gloom.
		vec3 hold = hemi * fill_in * (0.25 + 0.75 * gloom);
		vec3 lit = FLAME * lamps * lamp_power * (0.12 + 0.88 * gloom) + sunlit * (0.3 + 0.7 * gloom);
		vec3 glance = FLAME * lamps * glint * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
		EMISSION = mix(outside, (base * (hold + lit) + glance) * eyes, inside);
	} else {
		EMISSION = outside;
	}
}
