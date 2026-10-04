#ifndef ZS_NIGHT_SKY
#define ZS_NIGHT_SKY
// The night sky's styles, the player's choice in Settings > Night sky
// (scripts/look_pass.gd NIGHT_STYLES), like the cloud sea's: Nocturne
// (semi-real, rose Milky Way on teal-navy), Opal (pearl and iridescent, with
// the Opal sea), Storybook (painterly picture-book) and Mystic (aurora veils
// and slow-breathing light). Each lives in its own include and paints the
// dome's night, the Milky Way, the stars' look and the planet; the global
// zs_night_style picks one, so every pixel takes the same branch.
//
// The planet's shaders lay the shared parts on every style: an antialiased
// limb, a soft penumbra where the body shadows the rings (`shade` eases
// 0..1), and the rings' shadow on the body, taken from the style's own ring
// dust (so zs_*_planet_rings must stay cheap: the body calls it too).
//
// Included by the dome (shaders/reference_sky.gdshader), the stars
// (shaders/sky_stars.gdshader) and the planet (shaders/sky_planet.gdshaderinc).
#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/night_nocturne.gdshaderinc"
#include "res://shaders/night_opal.gdshaderinc"
#include "res://shaders/night_storybook.gdshaderinc"
#include "res://shaders/night_mystic.gdshaderinc"

vec3 zs_night_dome(vec3 col, float y, float deep) {
  if (zs_night_style == 1) return zs_opal_dome(col, y, deep);
  if (zs_night_style == 2) return zs_storybook_dome(col, y, deep);
  if (zs_night_style == 3) return zs_mystic_dome(col, y, deep);
  return zs_nocturne_dome(col, y, deep);
}

vec3 zs_night_light(vec3 room, float pixel) {
  if (zs_night_style == 1) return zs_opal_light(room, pixel);
  if (zs_night_style == 2) return zs_storybook_light(room, pixel);
  if (zs_night_style == 3) return zs_mystic_light(room, pixel);
  return zs_nocturne_light(room, pixel);
}

void zs_night_star(inout vec3 tint, inout float bright, inout float size, float kind, float seed, vec3 room) {
  if (zs_night_style == 1) zs_opal_star(tint, bright, size, kind, seed, room);
  else if (zs_night_style == 2) zs_storybook_star(tint, bright, size, kind, seed, room);
  else if (zs_night_style == 3) zs_mystic_star(tint, bright, size, kind, seed, room);
  else zs_nocturne_star(tint, bright, size, kind, seed, room);
}

vec4 zs_night_planet_body(vec3 p, vec3 radial, vec3 view, vec3 sun) {
  if (zs_night_style == 1) return zs_opal_planet_body(p, radial, view, sun);
  if (zs_night_style == 2) return zs_storybook_planet_body(p, radial, view, sun);
  if (zs_night_style == 3) return zs_mystic_planet_body(p, radial, view, sun);
  return zs_nocturne_planet_body(p, radial, view, sun);
}

vec4 zs_night_planet_rings(vec3 local, float fw, float lit, float shade) {
  if (zs_night_style == 1) return zs_opal_planet_rings(local, fw, lit, shade);
  if (zs_night_style == 2) return zs_storybook_planet_rings(local, fw, lit, shade);
  if (zs_night_style == 3) return zs_mystic_planet_rings(local, fw, lit, shade);
  return zs_nocturne_planet_rings(local, fw, lit, shade);
}

vec3 zs_night_planet_glow(float x, float side) {
  if (zs_night_style == 1) return zs_opal_planet_glow(x, side);
  if (zs_night_style == 2) return zs_storybook_planet_glow(x, side);
  if (zs_night_style == 3) return zs_mystic_planet_glow(x, side);
  return zs_nocturne_planet_glow(x, side);
}
#endif
