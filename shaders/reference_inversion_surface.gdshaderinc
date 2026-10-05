#include "res://shaders/reference_globals.gdshaderinc"
// Shared source weather.js inversion lid and post-fog surface density.
float zs_inversion_top(vec2 xz, float lid, float base) {
	float ripple = (zs_noise(xz * 0.3 + 31.0) - 0.5) * 0.5;
	if (zs_inversion.x > 0.77) return lid + ripple;
	float n = zs_noise(xz * 0.07 + 5.0) * 0.6 + zs_noise(xz * 0.19 + 17.0) * 0.4;
	float cover = smoothstep(0.0, 0.25, n + 0.6 - 1.5 * (1.0 - zs_inversion.x));
	return mix(base, lid + ripple, cover);
}

float zs_inversion_surface_amount(vec3 p) {
	float band = max(0.6, 0.12 * (zs_summit.y - 0.15));
	float lid = mix(0.15, zs_summit.y, zs_inversion.y);
	// Keep low morning mist on the landscape, not on the exposed display base.
	if (p.y < 0.0 || zs_inversion.x <= 0.001 || p.y >= lid + band) return 0.0;
	float top = zs_inversion.x > 0.77 && p.y < lid - 1.6 * band ? lid : zs_inversion_top(p.xz, lid, 0.15 - band);
	float depth = max(top + 0.2 * band - p.y, 0.0);
	// Match the volume's footprint; exposed island sides must not become a
	// white wall where the actual mist has already faded away.
	float footprint = 1.0 - smoothstep(0.75, 1.0, max(abs(p.x), abs(p.z)) / zs_plate_half);
	return (1.0 - exp(-depth * 0.9)) * smoothstep(0.0, 0.12, zs_inversion.x) * footprint;
}
