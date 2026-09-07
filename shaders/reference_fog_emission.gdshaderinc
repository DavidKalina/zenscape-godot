// Godot's fog injection truncates density-weighted emission to R11G11B10
// integers (scales 511, 511, 255). Thin neutral fog otherwise loses blue
// before red/green. Stochastic rounding preserves the expected RGB energy;
// native volume filtering/reprojection averages the sub-voxel noise.
// Caller supplies the final, boundary-masked density and a uniform [0,1) hash.
vec3 zs_fog_emission(vec3 color, float density, float rounding) {
	float weight = clamp(density, 0.0, 1.0);
	if (weight <= 0.001) return vec3(0.0);
	vec3 scale = vec3(511.0, 511.0, 255.0);
	vec3 packed = floor(clamp(color * weight, vec3(0.0), vec3(4.0)) * scale + rounding);
	// Stay just inside the integer bin after the engine's multiply/divide.
	return (packed + vec3(0.001)) / scale / weight;
}
