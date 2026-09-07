shader_type spatial;
render_mode cull_disabled, diffuse_lambert;

uniform vec4 base_color : source_color = vec4(1.0);
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/reference_cloud_field.gdshaderinc"
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
#include "res://shaders/reference_alpenglow.gdshaderinc"
#include "res://shaders/reference_inversion.gdshaderinc"
uniform float metalness_value = 0.0;
varying float inversion_transmit;
varying float glass;
uniform vec2 height_range = vec2(0.0, 1.0);
varying vec3 world_position;

uniform int ring_count = 1;
uniform vec4 centers_tau[32];
uniform vec4 axis_a_width[32];
uniform vec4 axis_b_thick[32];
uniform vec2 aer_steep[32];
uniform float section_white[12];
uniform float fall_seed = 0.0;
uniform float body_white = 0.0;
const vec3 ramp[7] = vec3[7](vec3(0.02842604, 0.21223076, 0.33245154), vec3(0.07036010, 0.33245154, 0.47932018), vec3(0.15896084, 0.47932018, 0.61049557), vec3(0.30054379, 0.63759687, 0.73046074), vec3(0.50888132, 0.78353779, 0.85499261), vec3(0.71569350, 0.87962240, 0.92158186), vec3(0.88792312, 0.93011086, 0.93868573));

void vertex() {
	int r = int(UV.x);
	float angle = UV.y;
	float tau = centers_tau[r].w;
	float total = centers_tau[ring_count - 1].w;
	float front = smoothstep(0.0, 0.5, zs_water_growth);
	float front_tau = front * total;
	int fi = 0;
	for (int j = 0; j < 30; j++) {
		if (fi < ring_count - 2 && centers_tau[fi + 1].w <= front_tau) fi++;
	}
	float f = clamp((front_tau - centers_tau[fi].w) / max(centers_tau[fi + 1].w - centers_tau[fi].w, 0.0001), 0.0, 1.0);
	vec3 center = mix(centers_tau[fi].xyz, centers_tau[fi + 1].xyz, f);
	vec3 impact = (MODEL_MATRIX * vec4(centers_tau[ring_count - 1].xyz, 1.0)).xyz;
	float gale = zs_wind_at(impact.xz) * (1.0 - zs_ice);
	if (tau > front_tau) {
		VERTEX = center + axis_a_width[fi].xyz * cos(angle) * axis_a_width[fi].w * 0.3
			+ axis_b_thick[fi].xyz * sin(angle) * axis_b_thick[fi].w * 0.4;
	} else {
		float steep = aer_steep[r].y;
		float aer = aer_steep[r].x;
		float t = zs_flow_time;
		float swell = 1.0 + sin(tau * 5.0 - t * 2.4 + angle * 2.0 + fall_seed) * (0.02 + steep * 0.06)
			+ sin(tau * 9.0 - t * 3.6 + angle * 3.0 + fall_seed) * (0.01 + steep * 0.04);
		float chop = 1.0 + aer * (sin(tau * 19.0 - t * 7.5 + angle * 4.0 + fall_seed * 3.0) * 0.11
			+ sin(tau * 13.0 - t * 5.1 + angle * 7.0 + fall_seed) * 0.08 - 0.11);
		VERTEX = centers_tau[r].xyz + axis_a_width[r].xyz * cos(angle) * axis_a_width[r].w * swell * chop
			+ axis_b_thick[r].xyz * sin(angle) * axis_b_thick[r].w * swell * chop;
		float drop = tau / max(total, 0.0001);
		VERTEX.xz += zs_wind_direction * 0.18 * gale * drop * drop * steep;
	}
	glass = 1.0 - aer_steep[r].x;
	int face_ring = int(UV2.x);
	float sw = section_white[int(UV2.y)];
	float aer = aer_steep[face_ring].x;
	float band = fract(centers_tau[face_ring].w * 1.8 - zs_flow_time * 1.6 + sw * 0.35);
	float white = 0.04 + body_white * aer + sw * (0.06 + 0.3 * aer) + aer * 0.66 + aer * gale * 0.12 + (band > 0.72 ? 0.16 * aer : 0.0);
	COLOR.rgb = mix(ramp[clamp(int(floor(white * 7.0)), 0, 6)], vec3(0.47932018, 0.60382734, 0.67244316), zs_ice * 0.85);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 tint = COLOR.rgb * base_color.rgb;
	vec3 face = normalize(cross(dFdx(world_position), dFdy(world_position)));
	vec3 eye = normalize(CAMERA_POSITION_WORLD - world_position);
	if (dot(face, eye) < 0.0) face = -face;
	vec3 view_face = normalize((VIEW_MATRIX * vec4(face, 0.0)).xyz);
	NORMAL = faceforward(view_face, -VIEW, view_face);
	ALBEDO = tint;
	EMISSION = vec3(0.07 * (1.0 - 0.5 * zs_ice), 0.12 * (1.0 - 0.4 * zs_ice), 0.14) * (0.12 + 0.88 * zs_daylight);
	EMISSION += tint * mix(zs_hemi_ground, zs_hemi_sky, face.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	EMISSION += zs_afterglow(world_position, face, tint);
	float g = smoothstep(0.45, 1.0, glass);
	float fresnel = (0.02 + 0.98 * pow(1.0 - clamp(dot(face, eye), 0.0, 1.0), 5.0)) * g * g * 0.55;
	vec3 reflected = reflect(-eye, face);
	vec3 sky = scene_linear_for_display(clamp(zsSkyGradient(vec3(reflected.x, abs(reflected.y), reflected.z)), vec3(0.0), vec3(0.98)));
	EMISSION = mix(EMISSION, sky, fresnel);
	inversion_transmit = zs_inversion_paint(world_position, EMISSION) * (1.0 - fresnel);
	ROUGHNESS = 0.55 - 0.25 * zs_ice;
}

#include "res://shaders/reference_direct_light.gdshaderinc"
