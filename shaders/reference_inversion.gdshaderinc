// Source weather.js wxInvTop/invAt. Shares the fixed patch field with its lid.
#include "res://shaders/reference_inversion_surface.gdshaderinc"
float zs_inversion_at(vec3 p) {
	float amount = smoothstep(0.0, 0.12, zs_inversion.x) * smoothstep(0.8, 1.0, zs_growth.x);
	if (amount < 0.002) return 0.0;
	float band = max(0.6, 0.12 * (zs_summit.y - 0.15));
	float lid = mix(0.15, zs_summit.y, zs_inversion.y);
	if (p.y > lid + band) return 0.0;
	float fade = 1.0 - smoothstep(0.75, 1.0, max(abs(p.x), abs(p.z)) / zs_plate_half);
	if (zs_inversion.x > 0.77 && p.y < lid - 1.6 * band) return 0.9 * amount * fade;
	float top = zs_inversion_top(p.xz, lid, 0.15 - band);
	if (p.y > top + band) return 0.0;
	if (top - p.y < 1.5 * band) {
		vec3 q = p * vec3(0.22, 0.42, 0.22) + vec3(zs_cloud_drift.x * 3.0, zs_motion_time * 0.012, zs_cloud_drift.z * 3.0);
		top += (wxFbm(q) - 0.5) * 0.9 * band;
	}
	return (1.0 - smoothstep(top - 0.5 * band, top + 0.35 * band, p.y)) * 0.9 * amount * fade;
}

// Native HDR counterpart of the source surface-color treatment. Requires display helper.
float zs_inversion_paint(vec3 p, inout vec3 emission) {
	if (zs_surface_post) return 1.0;
	float amount = zs_inversion_surface_amount(p);
	emission = mix(emission, scene_linear_for_display(clamp(zs_inversion_color, vec3(0.0), vec3(0.98))), amount);
	return 1.0 - amount;
}
