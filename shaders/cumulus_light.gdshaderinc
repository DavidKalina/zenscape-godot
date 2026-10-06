#ifndef ZS_CUMULUS_LIGHT
#define ZS_CUMULUS_LIGHT
// The light on cumulus, shared by the towering cumulus (shaders/
// sky_tower.gdshader) and the near cloud sea's heaps (shaders/
// sky_sea.gdshader), so the floor of heaps and the towers rising out of it
// are the one cloud: in the glide's clouds' own colours (zs_cloud_sun,
// zs_cloud_sky) but with a painter's contrast. The sun's side takes the
// sun's hue (gold, peach at golden hour), kept under white so it never
// bleaches; the shaded side and the crevices between lobes the sky's cool
// lavender-blue, darker under a bump, toward the foot and deep in the body;
// thin edges against the sun a silver or gold lining. Both shapes read the
// same tiling noise volume (scripts/cumulus_noise.gd): in red the
// cauliflower's round bumps, in green the soft wisps.
#include "res://shaders/reference_globals.gdshaderinc"

// The scene's exposure lifts what is drawn here about twice over: the
// cloud is lit at this share so its sunny side keeps the sun's hue rather
// than bleaching white.
const float ZS_CUMULUS_LIT_SHARE = 0.46;
// How fast cloud between a point and the sun shades it (per metre).
const float ZS_CUMULUS_SUN_SIGMA = 0.028;

// The sun's hue (deepened toward peach and gold as it gets low), its colour
// at no more than white, the shade's colour off the sky, and the lining's
// strength along `rd`.
void zs_cumulus_palette(vec3 rd, vec3 sun, out vec3 sun_hue, out vec3 sun_col, out vec3 shade_col, out float lining) {
	float toward_sun = max(dot(rd, sun), 0.0);
	float golden = smoothstep(0.35, 0.04, sun.y) * smoothstep(-0.1, 0.02, sun.y);
	float sun_level = max(max(zs_cloud_sun.r, zs_cloud_sun.g), max(zs_cloud_sun.b, 1e-3));
	sun_hue = zs_cloud_sun / sun_level;
	sun_hue *= mix(vec3(1.0), vec3(1.0, 0.8, 0.66), golden);
	sun_col = sun_hue * min(sun_level, 1.0);
	shade_col = zs_cloud_sky * vec3(1.3, 1.02, 0.98) * 1.55;
	lining = pow(toward_sun, 10.0) * 0.6 + pow(toward_sun, 60.0) * 1.6;
}

// How much of the sun reaches a point under `thick` of cloud toward it.
float zs_cumulus_sunlit(float thick) {
	return exp(-thick * ZS_CUMULUS_SUN_SIGMA);
}

// How dense the cloud is `inside` metres into its edge (soft over `soft`),
// thinned where the wisps (`wisp`, the noise's green) leave pockets.
float zs_cumulus_density(float inside, float soft, float wisp) {
	return smoothstep(0.0, soft, inside) * mix(0.55, 1.0, smoothstep(0.3, 0.68, wisp));
}

// A point's colour: `thick` the cloud toward the sun, `up_open` how open it
// is overhead (0 under a bump, 1 on top), `h` how high it stands in its
// cloud (0 at the foot, 1 at the crown), `deep` how far into the body
// (0 to 1), `density` its density (thin edges take the lining).
vec3 zs_cumulus_shade(vec3 sun_col, vec3 shade_col, float lining, float thick, float up_open, float h, float deep, float density) {
	float sunlit = zs_cumulus_sunlit(thick);
	// The sky's light, less of it where the sun's is strong, so the sunny
	// side keeps the sun's hue.
	vec3 ambient = shade_col * mix(0.4, 1.0, up_open) * mix(0.55, 1.0, h) * mix(1.0, 0.7, deep) * mix(1.0, 0.3, sunlit);
	vec3 direct = sun_col * (sunlit * 0.88 + exp(-thick * 0.004) * 0.1);
	// A lining on thin edges against the sun.
	vec3 rim = sun_col * lining * (1.0 - smoothstep(0.1, 0.9, density)) * exp(-thick * 0.012) * 2.2;
	return (ambient + direct + rim) * ZS_CUMULUS_LIT_SHARE;
}
#endif
