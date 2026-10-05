#ifndef ZS_SKY_CLOUD_SEA
#define ZS_SKY_CLOUD_SEA
// The cloud sea: the backdrop under the floating plate (scripts/look_pass.gd
// `cloud_sea`). The overview looks down on the plate, so almost all the sky
// behind it is dome below the horizon, where the hazed ridges (sky_ridges)
// never reach; it was one flat colour. Here that dome is a soft sea of cloud
// far below, seen in perspective, finer and lost in haze toward the horizon,
// where it meets the ridges' misty feet. It comes in three styles the player
// picks (Settings > Clouds; scripts/look_pass.gd `CLOUD_STYLES`), each in its
// own include: Opal (pearl puffs, rifts onto the land), Storybook (sculpted
// cumulus heaps, marched) and Mystic (pastel wisps, shafts, glow from below).
// Lit by the same sun and sky colours as the cloud deck, so it follows the
// hour, the weather and the look. At night it gives way to the stars except
// low down, under the band the starfield fills.
//
// Shared by the dome (shaders/reference_sky.gdshader, which defines
// ZS_CLOUD_SEA_SHADE to paint it) and the sky's real objects
// (shaders/sky_objects.gdshaderinc, which only ask how much it hides).
#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/sky_season.gdshaderinc"

// 0 paints nothing; the look pass sets it, and F6 turns it off with the rest.
uniform float cloud_sea = 0.0;

// How opaque the sea stands along a world direction, before its billows:
// clear above the horizon, fading in under it, and at night pulled down
// below the band where the stars and the planet hang.
float zs_sea_veil(vec3 dir) {
  if (cloud_sea <= 0.0 || dir.y > -0.02) return 0.0;
  float deep = zs_night * zs_celestial_clear;
  float under = smoothstep(-0.02, -0.16, dir.y);
  float night = smoothstep(-0.34, -0.66, dir.y);
  return cloud_sea * under * mix(1.0, night, deep);
}

// 1 where the sea leaves a sky object showing, 0 where it covers it.
float zs_sea_open(vec3 dir) {
  return 1.0 - zs_sea_veil(dir) * 0.92;
}

#ifdef ZS_CLOUD_SEA_SHADE
// Which style paints the sea: 0 Opal, 1 Storybook, 2 Mystic. A uniform, so
// every pixel takes the same branch and only the chosen style runs.
uniform int cloud_sea_style = 0;
#include "res://shaders/sky_cloud_sea_opal.gdshaderinc"
#include "res://shaders/sky_cloud_sea_storybook.gdshaderinc"
#include "res://shaders/sky_cloud_sea_mystic.gdshaderinc"

// Whether the chosen style is drawn with the deck in the half-resolution
// pass. Storybook was made there (its march is the dearest of the three);
// Opal and Mystic are drawn at full resolution, where they stay crisp.
bool zs_sea_half_res() {
  return cloud_sea_style == 1;
}

// How far each style takes the season's mood (shaders/sky_season.gdshaderinc):
// Opal, Storybook, Mystic. Mystic's pastels carry their own colour, so less.
// Night has its own palette (night_sky), so the mood all but leaves by dark.
const vec3 SEA_SEASON_MOOD = vec3(1.0, 0.9, 0.6);
const float SEA_SEASON_NIGHT = 0.8;

// The sea along `dir` (world) / `room` (the room's turn of it), premultiplied,
// in the chosen style, in the season's mood. `horizon` is the sky's colour
// along the flattened direction, `below` the dome's own colour along `dir`.
vec4 zs_cloud_sea(vec3 dir, vec3 room, vec3 horizon, vec3 below) {
  vec4 sea;
  float mood;
  if (cloud_sea_style == 1) {
    sea = zs_cloud_sea_storybook(dir, room, horizon, below);
    mood = SEA_SEASON_MOOD.y;
  } else if (cloud_sea_style == 2) {
    sea = zs_cloud_sea_mystic(dir, room, horizon, below);
    mood = SEA_SEASON_MOOD.z;
  } else {
    sea = zs_cloud_sea_opal(dir, room, horizon, below);
    mood = SEA_SEASON_MOOD.x;
  }
  sea.rgb = zs_sky_season_grade(sea.rgb, mood * (1.0 - SEA_SEASON_NIGHT * zs_night));
  return sea;
}
#endif
#endif
