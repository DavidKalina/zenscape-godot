// The grass's silvery underside, flipped into view by the wind (endless
// flight, docs/design/endless-flight/grass-silver-handoff.md). A blade's
// underside is a paler, silvery sage; where the breeze's waves and gusts
// bow the blades they twist and show it, so bright bands run downwind with
// the gusts. One field for every tier: the near tufts read it from their
// own bow (reference_surface `grass_bow`, so anything that bows them shows
// it), the far tufts and the painted ground from zs_silver_bow, the same
// lean with its finer parts faded to their mean as a pixel outgrows them,
// so the bands carry on past the tufts with no ring. Include after
// reference_wind (and grass_look's zs_grass_offset).
//
// Opt-in: `grass_silver.x` 0 (the default) draws nothing and costs nothing.
#ifndef ZS_GRASS_SILVER
#define ZS_GRASS_SILVER

// x strength (0 off), y..z the drive (zs_silver_drive's `w`) over which
// the underside comes into view, w how much brighter the underside reads
// than the blade's face.
uniform vec4 grass_silver = vec4(0.0, 0.25, 1.25, 1.3);
// The underside's hue (linear; only its hue and saturation count, the
// brightness is the blade's own times grass_silver.w), and how much of the
// blade's own colour it keeps (so regions and drifts still show through).
uniform vec3 grass_silver_colour = vec3(0.42, 0.62, 0.55);
// Each region's (shaders/region_paint.gdshaderinc), where a region map is drawn.
uniform vec3 grass_silver_colour_r[4];
uniform float grass_silver_keep : hint_range(0.0, 1.0) = 0.45;
// The three wave trains the undersides ride (m between crests): the
// tufts' own (ZS_BREEZE_WAVE_LENGTH) and the painted ground's two
// (endless_ground `wave_lengths`), and each one's share.
uniform vec3 grass_silver_waves = vec3(9.0, 22.0, 60.0);
uniform vec3 grass_silver_share = vec3(0.25, 0.35, 0.4);

// 0..1: how far the underside is turned into view at `p`, a pixel there
// `fp` m across. The breeze's wave crests rolling downwind on the air's
// travel (the tufts' 9 m ones and the ground's longer two, zs_wave_crest_at),
// swelled and calmed by the slow gust bands (zs_gust_band_at, 30 by 18 m)
// and the breeze's strength, and lifted by any gust front. Each train fades
// to its mean as the pixel outgrows it, so far off only the long ones roll.
float zs_silver_drive(vec2 p, float fp) {
	float travel = zs_gust_distance;
	vec3 crest = vec3(
		zs_wave_crest_at(p, grass_silver_waves.x, ZS_BREEZE_WAVE_SPEED, zs_grass_offset, travel),
		zs_wave_crest_at(p, grass_silver_waves.y, ZS_BREEZE_WAVE_SPEED, zs_grass_offset, travel),
		zs_wave_crest_at(p * 0.97 + 50.0, grass_silver_waves.z, ZS_BREEZE_WAVE_SPEED * 1.3, zs_grass_offset + 7.0, travel));
	vec3 keep = vec3(1.0) - smoothstep(grass_silver_waves * 0.08, grass_silver_waves * 0.3, vec3(fp));
	crest = mix(vec3(0.4), crest, keep);
	float band = zs_gust_band_at(p, travel);
	float w = dot(crest, grass_silver_share) * band * zs_breeze_air() / 0.53;
	w += zs_front_at(p, 0.0) * 1.5;
	return smoothstep(grass_silver.y, grass_silver.z, w);
}

// A near tuft's: the same at its root, and more where something bows it
// past the breeze's usual (`bow`, reference_surface `grass_bow`: a gust
// front, the wind tool, a wake), the extra capped at ZS_SILVER_BOW_MAX so
// grass pressed flat (the plane's wash) turns part way, not to white.
const float ZS_SILVER_BOW_MAX = 0.35;
// With silver on, the share of grass_react's paling the stirred grass keeps
// (the underside already shows it's stirred; both at full read as white).
const float ZS_SILVER_REACT_PALE = 0.5;
float zs_silver_tuft(vec2 root, float bow) {
	return clamp(zs_silver_drive(root, 0.0) + min(max(bow - 0.55, 0.0) * 1.5, ZS_SILVER_BOW_MAX), 0.0, 1.0);
}

// The underside's colour for a blade (or turf) of colour `c`.
// `sc` the underside's hue (grass_silver_colour, or a region's at the spot).
vec3 zs_silver_under_hue(vec3 c, vec3 sc) {
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	vec3 hue = sc / max(dot(sc, vec3(0.2126, 0.7152, 0.0722)), 0.01);
	return mix(hue * l, c, grass_silver_keep) * grass_silver.w;
}

vec3 zs_silver_under(vec3 c) {
	return zs_silver_under_hue(c, grass_silver_colour);
}

// `c` with its underside shown: `flip` (zs_silver_drive) how far it is
// turned, `up` 0..1 how much of it can turn (a blade's upper part; 1 the
// turf), `side` how much this face is the underside (0.8 the mean).
vec3 zs_silver_paint_hue(vec3 c, float flip, float up, float side, vec3 sc) {
	return mix(c, zs_silver_under_hue(c, sc), clamp(grass_silver.x * flip * up * side, 0.0, 1.0));
}

vec3 zs_silver_paint(vec3 c, float flip, float up, float side) {
	return zs_silver_paint_hue(c, flip, up, side, grass_silver_colour);
}
// How much a blade's face seen here is its underside, 0.55..1.05 (mean
// 0.8): the face turned downwind is the bowed blade's back. `dx`, `dy` the
// world position's screen derivatives, `to_eye` toward the eye, `wind` the
// wind's way (zs_wind_direction). A two-sided look with no twist in the mesh.
float zs_silver_side(vec3 dx, vec3 dy, vec3 to_eye, vec2 wind) {
	vec3 n = cross(dx, dy);
	if (dot(n, to_eye) < 0.0) n = -n;
	float flat_len = length(n.xz);
	float downwind = flat_len > 1.0e-9 ? dot(n.xz / flat_len, wind) : 0.0;
	return 0.8 + 0.25 * downwind;
}
#endif
