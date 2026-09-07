// Source water.js waterVolume/uLook and lake-ice.js roughness.
uniform vec2 lake_look = vec2(0.95, 1.0);
uniform vec4 lake_volume = vec4(0.45, 0.0, 0.72, 0.4);
uniform bool source_lake_material = true;
float zs_lake_opacity(float depth, float ice) {
	float absorption = max(1.0 - exp(-max(depth, 0.0) / lake_volume.x), ice);
	return max(lake_look.x, 0.95 + 0.05 * ice) * mix(lake_volume.w, 1.0, absorption);
}
float zs_lake_reflection(float facing) {
	return (0.02 + 0.98 * pow(1.0 - clamp(facing, 0.0, 1.0), 5.0)) * lake_volume.z;
}
float zs_lake_roughness(float ice, vec3 detail) {
	float roughness = min(lake_look.y, 1.0 - 0.5 * ice);
	float ice_roughness = mix(mix(0.66, 0.22, detail.y), 0.94, detail.z);
	return mix(roughness, ice_roughness, detail.x);
}
