#ifndef ZS_NIGHT_NOCTURNE
#define ZS_NIGHT_NOCTURNE
// The Nocturne night sky: one of the player's night styles
// (shaders/night_sky.gdshaderinc picks it by zs_night_style; scripts/look_pass.gd
// sets that). Everything it paints is in this file, as pure functions of
// their arguments and the shader globals, so the dome, the stars and the
// planet can each include it. Its names carry the style.
#include "res://shaders/night_noise.gdshaderinc"

// The dome at night: `col` is the sky's own colour along the direction, `y`
// the direction's height, `deep` how fully night and clear it is (0..1).
// Returns the dome's colour, before the Milky Way and the stars.
vec3 zs_nocturne_dome(vec3 col, float y, float deep) {
  // A deep teal-navy, lighter toward the horizon line either side, keeping
  // a little of the look's own sky so moods still tint it.
  float lift = exp(-abs(y) / 0.22);
  vec3 navy = mix(vec3(0.022, 0.058, 0.1), vec3(0.075, 0.17, 0.21), lift);
  vec3 night = mix(navy, col * 0.4, 0.25);
  night += vec3(0.02, 0.05, 0.035) * exp(-abs(y) / 0.035) * 0.3;
  return mix(col, night, deep);
}

// The sky's painted night light along the room direction `room` (the Milky
// Way, and whatever veils the style hangs): display colour, which the dome
// scales by how much the stars show. `pixel` is radians per screen pixel.
// A smooth dusty-rose river: its noise is stretched along the band so the
// structure runs as filaments, and the dust lanes are long and coherent.
// Eight noise calls on band pixels, none elsewhere.
vec3 zs_nocturne_light(vec3 room, float pixel) {
  vec3 n = normalize(vec3(0.6, 0.25, 0.75));
  float d = dot(room, n);
  if (abs(d) > 0.55) return vec3(0.0);
  vec3 centre = normalize(cross(n, vec3(0.0, 1.0, 0.0)));
  float core = pow(max(dot(room, centre), 0.0), 2.0);
  // A slow wander of the band's spine.
  float wx = zs_night_noise(room * 1.7 + 1.3);
  float wy = zs_night_noise(room * 2.9 + 7.1);
  float off = d + wx * 0.06 + wy * 0.02;
  float width = mix(0.12, 0.2, core);
  float band = exp(-off * off / (width * width));
  if (band < 0.01) return vec3(0.0);
  // Stretch the pattern along the band (its across-band part is scaled up).
  vec3 along = room - n * d;
  vec3 q = along + n * d * 4.0 + vec3(wx, wy, wx - wy) * 0.15;
  float billow = zs_night_fbm(q * 3.0, 3, pixel * 3.0);
  float glow = band * mix(0.55, 1.0, smoothstep(0.25, 0.7, billow));
  float r = zs_night_fbm(q * 6.0 + 5.0, 3, pixel * 6.0);
  float ridge = 1.0 - abs(r * 2.0 - 1.0);
  float wisps = smoothstep(0.55, 1.0, ridge) * band;
  float lane2 = zs_night_fbm(q * 2.2 + 17.0, 2, pixel * 2.2);
  float lanes = smoothstep(0.47, 0.64, lane2) * exp(-off * off / (width * width * 0.45));
  // One long dark rift down the spine, broken by the noise.
  float rift = exp(-pow((off - 0.012) / 0.016, 2.0)) * smoothstep(0.4, 0.62, billow);
  float dark = clamp(0.75 * lanes + 0.35 * rift, 0.0, 0.72);
  vec3 haze = vec3(0.05, 0.09, 0.13) * band;
  vec3 rose = mix(vec3(0.9, 0.18, 0.22), vec3(1.0, 0.5, 0.28), clamp(core * 0.8 + 0.25 * billow, 0.0, 1.0));
  return (haze * 0.5 + rose * (glow * 0.5 + wisps * 0.14 + core * band * 0.1)) * (1.0 - dark);
}

// A star as the style sees it (shaders/sky_stars.gdshader): `tint` its
// colour, `bright` its brightness (a hero's is HDR power), `size` a scale
// on its width (1 as drawn). `kind` 0 field, 1 hero, 2 breather; `seed`
// 0..1 per star; `room` its direction.
void zs_nocturne_star(inout vec3 tint, inout float bright, inout float size, float kind, float seed, vec3 room) {
  // A few stars a touch warm, a few a touch cool, none strong.
  tint = mix(tint, mix(vec3(1.0, 0.88, 0.76), vec3(0.8, 0.9, 1.0), step(0.5, fract(seed * 7.3))), 0.18 * step(0.6, seed));
}

// The planet's body at a point: `p` the point on the unit sphere in the
// planet's own (slowly spinning) frame, `radial` its world normal, `view`
// the world direction to it from the eye, `sun` the sun's direction.
// rgb: display colour; a: how much shows by day (the night shows it whole).
// A painted gas giant: many soft latitude bands, streaked turbulence, limb
// darkening and a thin atmospheric rim.
vec4 zs_nocturne_planet_body(vec3 p, vec3 radial, vec3 view, vec3 sun) {
  float fwy = fwidth(p.y);
  float lit = smoothstep(-0.2, 0.9, dot(radial, sun));
  // At night the real sun may be far round the other side: a soft key
  // from upper left and a little behind the eye keeps the face painted.
  vec3 key = normalize(vec3(-0.55, 0.6, 0.0) - view * 0.55);
  lit = mix(lit, smoothstep(-0.25, 0.95, dot(radial, key)) * 0.92 + 0.08, zs_night);
  float mu = clamp(dot(radial, -view), 0.0, 1.0);
  // Streaks run along the latitudes: the noise is squeezed along y.
  float turb = zs_night_noise(vec3(p.x * 2.2, p.y * 7.0, p.z * 2.2));
  float lat = p.y + 0.018 * turb;
  float keep1 = 1.0 - smoothstep(0.15, 0.5, fwy * 24.0);
  float keep2 = 1.0 - smoothstep(0.15, 0.5, fwy * 60.0);
  float big = 0.5 + 0.5 * sin(lat * 9.0 + 1.1 * sin(lat * 3.1 + 0.6));
  float mid = 0.5 + 0.5 * sin(lat * 23.0 + 2.0 + 1.6 * turb) ;
  float fine = 0.5 + 0.5 * sin(lat * 57.0 + 4.0 * turb);
  vec3 cream = vec3(0.98, 0.83, 0.55);
  vec3 ochre = vec3(0.86, 0.58, 0.3);
  vec3 rust = vec3(0.62, 0.33, 0.22);
  vec3 grey = vec3(0.66, 0.68, 0.66);
  vec3 base = mix(rust, cream, big);
  base = mix(base, ochre, mid * 0.45 * keep1);
  base = mix(base, cream, fine * 0.22 * keep2);
  base = mix(base, grey, smoothstep(0.75, 0.99, abs(p.y)) * 0.3);
  base = mix(vec3(dot(base, vec3(0.3, 0.55, 0.15))), base, 1.25);
  // Soft limb darkening toward the edge.
  float limb = pow(mu, 0.45);
  vec3 col = base * (0.06 + 0.94 * lit) * mix(0.45, 1.0, limb);
  // A thin pale rim of atmosphere.
  float rim = pow(1.0 - mu, 4.0);
  col += vec3(0.7, 0.74, 0.8) * rim * (0.04 + 0.16 * lit);
  float day = smoothstep(-0.35, 0.5, dot(radial, sun));
  return vec4(clamp(col, 0.0, 1.0), max(lit, rim * day) * 0.35);
}

// The rings at a point: `local` the point in the ring plane (xz, in planet
// radii; the mesh spans radii 1.38 to 2.3), `fw` the screen footprint of a
// unit of radius, `lit` how squarely the sun strikes the ring plane, `shade`
// 1 in sunlight and 0 in the planet's shadow.
// rgb: display colour; a: density (opacity at night).
// A faint inner ring, a bright broad one, a Cassini-like gap, an outer ring
// with a thin gap, each cut into many fine lanes that fade as they thin
// below a pixel.
vec4 zs_nocturne_planet_rings(vec3 local, float fw, float lit, float shade) {
  float r = length(local.xz);
  float k1 = 1.0 - smoothstep(0.2, 0.55, fw * 12.0);
  float k2 = 1.0 - smoothstep(0.2, 0.55, fw * 28.0);
  float k3 = 1.0 - smoothstep(0.2, 0.55, fw * 60.0);
  float lanes = 0.5 + 0.5 * zs_night_noise(vec3(r * 12.0, 1.7, 0.3)) * k1
    + 0.28 * zs_night_noise(vec3(r * 28.0, 4.1, 2.2)) * k2
    + 0.16 * zs_night_noise(vec3(r * 60.0, 8.3, 5.0)) * k3;
  lanes = clamp(lanes, 0.25, 1.1);
  float inner = smoothstep(1.38, 1.56, r);
  float outer = 1.0 - smoothstep(2.24, 2.3, r);
  float cassini = 1.0 - 0.92 * exp(-pow((r - 1.99) / 0.035, 2.0));
  float encke = 1.0 - 0.7 * exp(-pow((r - 2.2) / 0.012, 2.0));
  float ringB = smoothstep(1.52, 1.62, r) * (1.0 - smoothstep(1.93, 1.97, r));
  float body = mix(0.3, 1.0, ringB);
  float density = inner * outer * cassini * encke * lanes * body;
  float s = mix(shade, 0.5, clamp(fwidth(shade), 0.0, 1.0));
  float light = (0.25 + 0.75 * lit) * mix(0.08, 1.0, s);
  vec3 tint = mix(vec3(0.72, 0.6, 0.48), vec3(0.93, 0.85, 0.7), ringB);
  tint = mix(tint, vec3(0.8, 0.76, 0.68), step(2.0, r) * 0.5);
  return vec4(tint * (0.06 + 0.9 * light) * (0.8 + 0.3 * lanes), density * 0.85);
}

// The planet's glow round its disc, added: `x` the distance from its centre
// in planet radii (the card reaches 1.6), `side` 0..1 how far toward the sun.
vec3 zs_nocturne_planet_glow(float x, float side) {
  float glow = x > 1.0 ? exp(-(x - 1.0) / 0.12) * 0.35 + exp(-(x - 1.0) / 0.4) * 0.12 : pow(x, 12.0) * 0.12;
  glow *= 1.0 - smoothstep(1.2, 1.6, x);
  return vec3(0.85, 0.82, 0.78) * glow * (0.2 + 0.8 * side) * 0.4;
}
#endif
