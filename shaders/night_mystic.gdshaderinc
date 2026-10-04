#ifndef ZS_NIGHT_MYSTIC
#define ZS_NIGHT_MYSTIC
// The Mystic night sky: one of the player's night styles
// (shaders/night_sky.gdshaderinc picks it by zs_night_style; scripts/look_pass.gd
// sets that). Everything it paints is in this file, as pure functions of
// their arguments and the shader globals, so the dome, the stars and the
// planet can each include it. Its names carry the style.
#include "res://shaders/night_noise.gdshaderinc"

// The dome at night: `col` is the sky's own colour along the direction, `y`
// the direction's height, `deep` how fully night and clear it is (0..1).
// Returns the dome's colour, before the Milky Way and the stars.
vec3 zs_mystic_dome(vec3 col, float y, float deep) {
  // A deep teal-navy, lighter toward the horizon line either side, keeping
  // a little of the look's own sky so moods still tint it.
  float lift = exp(-abs(y) / 0.22);
  vec3 navy = mix(vec3(0.018, 0.04, 0.085), vec3(0.06, 0.13, 0.18), lift);
  vec3 night = mix(navy, col * 0.4, 0.25);
  night += vec3(0.02, 0.05, 0.035) * exp(-abs(y) / 0.035) * 0.3;
  return mix(col, night, deep);
}

// The sky's painted night light along the room direction `room` (the Milky
// Way, and whatever veils the style hangs): display colour, which the dome
// scales by how much the stars show. `pixel` is radians per screen pixel.
vec3 zs_mystic_light(vec3 room, float pixel) {
  vec3 n = normalize(vec3(0.6, 0.25, 0.75));
  float d = dot(room, n);
  if (abs(d) > 0.5) return vec3(0.0);
  vec3 centre = normalize(cross(n, vec3(0.0, 1.0, 0.0)));
  float core = pow(max(dot(room, centre), 0.0), 2.0);
  vec3 w = vec3(zs_night_noise(room * 2.5 + 1.3), zs_night_noise(room * 2.5 + 7.1), 0.0) * 0.5;
  float off = d + w.x * 0.14 + w.y * 0.05;
  float width = mix(0.13, 0.22, core);
  float band = exp(-off * off / (width * width));
  if (band < 0.01) return vec3(0.0);
  float billow = zs_night_fbm(room * 3.5 + w * 1.6, 4, pixel * 3.5);
  float glow = band * mix(0.35, 1.0, smoothstep(0.25, 0.8, billow * 0.8 + band * 0.35));
  float ridge = 1.0 - abs(zs_night_fbm(room * 5.0 + w * 2.2 + 5.0, 4, pixel * 5.0) * 2.0 - 1.0);
  float lanes = smoothstep(0.76, 0.94, ridge) * exp(-off * off / (width * width * 0.35));
  vec3 haze = vec3(0.1, 0.13, 0.2) * band;
  vec3 rose = mix(vec3(0.42, 0.13, 0.2), vec3(0.62, 0.32, 0.28), core * 0.7 + 0.3 * smoothstep(0.55, 0.85, billow));
  return (haze * 0.35 + rose * glow * 0.38) * (1.0 - 0.85 * lanes);
}

// A star as the style sees it (shaders/sky_stars.gdshader): `tint` its
// colour, `bright` its brightness (a hero's is HDR power), `size` a scale
// on its width (1 as drawn). `kind` 0 field, 1 hero, 2 breather; `seed`
// 0..1 per star; `room` its direction.
void zs_mystic_star(inout vec3 tint, inout float bright, inout float size, float kind, float seed, vec3 room) {
}

// The planet's body at a point: `p` the point on the unit sphere in the
// planet's own (slowly spinning) frame, `radial` its world normal, `view`
// the world direction to it from the eye, `sun` the sun's direction.
// rgb: display colour; a: how much shows by day (the night shows it whole).
vec4 zs_mystic_planet_body(vec3 p, vec3 radial, vec3 view, vec3 sun) {
  float lit = smoothstep(-0.12, 0.85, dot(radial, sun));
  float lat = p.y + 0.06 * sin(p.x * 7.0 + p.z * 5.0) + 0.04 * sin(atan(p.z, p.x) * 3.0 + p.y * 11.0);
  float band = 0.5 + 0.5 * sin(lat * 13.0 + 1.3 * sin(lat * 4.0));
  float fine = 0.5 + 0.5 * sin(lat * 41.0 + 2.0);
  vec3 base = mix(vec3(0.62, 0.38, 0.29), vec3(0.93, 0.84, 0.68), band);
  base = mix(base, vec3(0.86, 0.6, 0.42), fine * 0.35 * (1.0 - abs(p.y)));
  vec3 col = base * (0.035 + 0.9 * lit);
  float limb = pow(1.0 - max(dot(radial, -view), 0.0), 3.0);
  float day = smoothstep(-0.35, 0.5, dot(radial, sun));
  col += vec3(0.55, 0.8, 1.0) * limb * (0.08 + 0.55 * day);
  return vec4(clamp(col, 0.0, 1.0), max(lit, limb * day) * 0.35);
}

// The rings at a point: `local` the point in the ring plane (xz, in planet
// radii; the mesh spans radii 1.38 to 2.3), `fw` the screen footprint of a
// unit of radius, `lit` how squarely the sun strikes the ring plane, `shade`
// 1 in sunlight and 0 in the planet's shadow.
// rgb: display colour; a: density (opacity at night).
vec4 zs_mystic_planet_rings(vec3 local, float fw, float lit, float shade) {
  float r = length(local.xz);
  float lanes = 0.6 + 0.4 * sin(r * 44.0) * (1.0 - smoothstep(0.02, 0.06, fw));
  float gap = 1.0 - 0.85 * exp(-pow((r - 1.86) / 0.04, 2.0));
  float density = smoothstep(1.38, 1.5, r) * (1.0 - smoothstep(2.15, 2.3, r)) * lanes * gap;
  float light = (0.25 + 0.75 * lit) * mix(0.08, 1.0, shade);
  return vec4(vec3(0.86, 0.79, 0.66) * (0.05 + 0.85 * light), density * 0.7);
}

// The planet's glow round its disc, added: `x` the distance from its centre
// in planet radii (the card reaches 1.6), `side` 0..1 how far toward the sun.
vec3 zs_mystic_planet_glow(float x, float side) {
  float glow = x > 1.0 ? exp(-(x - 1.0) / 0.1) * 0.8 + exp(-(x - 1.0) / 0.35) * 0.25 : pow(x, 8.0) * 0.5;
  glow *= 1.0 - smoothstep(1.28, 1.6, x);
  return vec3(0.55, 0.8, 1.0) * glow * (0.15 + 0.85 * side) * 0.35;
}
#endif
