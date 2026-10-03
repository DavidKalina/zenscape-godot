#ifndef ZS_SKY_CLOUD_SEA
#define ZS_SKY_CLOUD_SEA
// The cloud sea: the backdrop under the floating plate (scripts/look_pass.gd
// `cloud_sea`). The overview looks down on the plate, so almost all the sky
// behind it is dome below the horizon, where the hazed ridges (sky_ridges)
// never reach; it was one flat colour. Here that dome is a soft sea of cloud
// far below, seen in perspective: broad billows straight down, finer and
// lost in haze toward the horizon, where it meets the ridges' misty feet.
// Lit by the same sun and sky colours as the cloud deck, so it follows the
// hour, the weather and the look. At night it gives way to the stars except
// low down, under the band the starfield fills.
//
// Shared by the dome (shaders/reference_sky.gdshader, which defines
// ZS_CLOUD_SEA_SHADE to paint it) and the sky's real objects
// (shaders/sky_objects.gdshaderinc, which only ask how much it hides).
#include "res://shaders/reference_globals.gdshaderinc"

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
float zs_sea_hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float zs_sea_noise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(zs_sea_hash(i), zs_sea_hash(i + vec2(1.0, 0.0)), f.x),
             mix(zs_sea_hash(i + vec2(0.0, 1.0)), zs_sea_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
// Rounded billows: value noise whose finer octaves fade out where they
// would shimmer (`blur` is the pattern's footprint per pixel), so the far
// sea goes smooth instead of crawling.
float zs_sea_billows(vec2 q, float blur) {
  float h = 0.0;
  float amp = 0.5;
  float freq = 1.0;
  float total = 0.0;
  for (int o = 0; o < 4; o++) {
    float keep = 1.0 - smoothstep(0.25, 0.7, blur * freq);
    h += zs_sea_noise(q * freq + vec2(float(o) * 7.3, float(o) * 3.1)) * amp * keep + 0.5 * amp * (1.0 - keep);
    total += amp;
    freq *= 2.07;
    amp *= 0.5;
  }
  return h / total;
}

// The sea along `dir` (world) / `room` (the room's turn of it), premultiplied:
// rgb already times alpha. `horizon` is the sky's colour along the flattened
// direction, the haze it dissolves into; `below` the dome's own colour along
// `dir`, which the sea keeps as its tone so the backdrop stays the look's.
vec4 zs_cloud_sea(vec3 dir, vec3 room, vec3 horizon, vec3 below) {
  float veil = zs_sea_veil(dir);
  if (veil <= 0.0) return vec4(0.0);
  float down = max(-dir.y, 0.02);
  // Where the ray meets the sea, in depths below the eye.
  vec2 at = room.xz / down;
  float far = length(at);
  // Broad billows, drifting slowly.
  vec2 q = at * 0.95 + vec2(0.6, 0.35) * zs_motion_time * 0.004;
  float blur = length(fwidth(q));
  float h = zs_sea_billows(q, blur);
  // The side of each billow that faces the sun, by a step toward it.
  vec3 sun_room = zsRoomDir(zs_sun_direction);
  vec2 toward = normalize(sun_room.xz + 1e-4);
  float ahead = zs_sea_billows(q + toward * 0.08, blur);
  float lit = clamp((h - ahead) * 6.0 + 0.5, 0.0, 1.0);
  // Mostly one sea, a few darker troughs between the billows.
  float cover = smoothstep(0.32, 0.66, h);
  // Calm overcast: flatter light, less relief.
  float relief = mix(1.0, 0.5, smoothstep(0.35, 0.9, zs_cloud.x));
  // Air between the eye and the far sea: the tone lifts toward the
  // horizon's glow and the billows fade into it.
  float haze = 1.0 - exp(-far * 0.3);
  vec3 tone = mix(below, horizon, haze);
  float shade = mix(0.5, cover * (0.45 + 0.55 * lit), relief);
  float near = 1.0 - haze;
  vec3 col = tone * mix(1.0, mix(0.8, 1.16, shade), 0.2 + 0.8 * near);
  // Sunlit tops take the deck's sun colour (the moon's at night, a little
  // stronger, so the sea under the stars still reads).
  col += zs_cloud_sun * cover * lit * relief * near * mix(0.05, 0.12, zs_night * zs_celestial_clear);
  return vec4(col * veil, veil);
}
#endif
#endif
