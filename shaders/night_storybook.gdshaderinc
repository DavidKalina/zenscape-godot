#ifndef ZS_NIGHT_STORYBOOK
#define ZS_NIGHT_STORYBOOK
// The Storybook night sky: one of the player's night styles
// (shaders/night_sky.gdshaderinc picks it by zs_night_style; scripts/look_pass.gd
// sets that). A painterly picture-book night, gouache on indigo paper: soft
// pools of pigment, a Milky Way brushed in long cream and peach strokes, a
// few deliberate round stars, and an illustrated ringed planet. Everything it
// paints is in this file, as pure functions of their arguments and the
// shader globals, so the dome, the stars and the planet can each include it.
// Its names carry the style.
#include "res://shaders/night_noise.gdshaderinc"

// The dome at night: `col` is the sky's own colour along the direction, `y`
// the direction's height, `deep` how fully night and clear it is (0..1).
// Returns the dome's colour, before the Milky Way and the stars.
vec3 zs_storybook_dome(vec3 col, float y, float deep) {
  // Deep indigo above, ultramarine pooling toward the horizon line either
  // side, keeping a little of the look's own sky so moods still tint it.
  float lift = exp(-abs(y) / 0.3);
  vec3 indigo = vec3(0.022, 0.03, 0.105);
  vec3 ultra = vec3(0.045, 0.085, 0.23);
  vec3 night = mix(indigo, ultra, lift);
  night = mix(night, col * 0.45, 0.15);
  night += vec3(0.05, 0.035, 0.07) * exp(-abs(y) / 0.05) * 0.4;
  return mix(col, night, deep);
}

// The sky's painted night light along the room direction `room` (the Milky
// Way, and whatever veils the style hangs): display colour, which the dome
// scales by how much the stars show. `pixel` is radians per screen pixel.
vec3 zs_storybook_light(vec3 room, float pixel) {
  // Washes of pigment: broad soft pools of ultramarine and violet with
  // gently uneven edges, two octaves, so the sky is never one flat tone.
  float w1 = zs_night_noise(room * 1.3 + 4.1);
  float w2 = zs_night_noise(room * 2.1 + 11.7 + w1 * 0.4);
  float pool = smoothstep(-0.1, 0.5, w1);
  float pool2 = smoothstep(0.0, 0.55, w2) * (1.0 - 0.5 * pool);
  vec3 wash = vec3(0.012, 0.035, 0.12) * pool + vec3(0.04, 0.02, 0.075) * pool2;

  // The ribbon: a great circle's frame. uv runs along it, d across it.
  vec3 n = normalize(vec3(0.6, 0.25, 0.75));
  vec3 e1 = normalize(cross(n, vec3(0.0, 1.0, 0.0)));
  vec3 e2 = cross(n, e1);
  float d = dot(room, n);
  if (abs(d) > 0.6) return wash;
  vec2 uv = vec2(dot(room, e1), dot(room, e2));
  float along = atan(uv.y, uv.x);
  // The core swells where it passes the galactic heart, e1.
  float core = smoothstep(-0.2, 0.9, uv.x);
  // The spine wanders; the edges curl a little more, lazily.
  float meander = zs_night_noise(vec3(uv * 0.9, d * 1.5 + 2.0));
  float off = d + meander * 0.11;
  float edge = smoothstep(0.1, 0.34, abs(off));
  off += edge * 0.08 * sin(along * 7.0 + meander * 5.0 + zs_night_noise(vec3(uv * 1.7, 6.0)) * 3.0);
  float width = mix(0.095, 0.17, core);
  float band = exp(-off * off / (width * width));
  if (band < 0.01) return wash;
  // Brush strokes: noise drawn long along the ribbon, short across it.
  vec3 sp = vec3(uv * 3.0, off * 15.0);
  float stroke = zs_night_fbm(sp, 3, pixel * 15.0);
  float fine = zs_night_noise(vec3(uv * 3.4, off * 26.0 + 7.0)) * (1.0 - smoothstep(0.1, 0.3, pixel * 26.0));
  float paint = band * mix(0.2, 1.0, smoothstep(0.38, 0.62, stroke + 0.12 * fine + band * 0.2));
  // Dry-brush gaps: a few soft dark lanes along the strokes.
  float ridge = 1.0 - abs(zs_night_noise(vec3(uv * 1.3 + 3.0, off * 7.0 + 1.0)) * 1.6);
  float lanes = smoothstep(0.55, 0.95, ridge) * smoothstep(0.35, 0.6, stroke) * exp(-off * off / (width * width * 0.4));
  paint *= 1.0 - 0.7 * lanes;
  vec3 cream = vec3(1.0, 0.68, 0.32);
  vec3 peach = vec3(1.0, 0.38, 0.3);
  vec3 tone = mix(peach, cream, smoothstep(0.1, 0.65, paint) * 0.8 + core * 0.2);
  vec3 haze = vec3(0.05, 0.035, 0.12) * band * 0.3;
  return wash + haze + tone * paint * 0.55;
}

// A star as the style sees it (shaders/sky_stars.gdshader): `tint` its
// colour, `bright` its brightness (a hero's is HDR power), `size` a scale
// on its width (1 as drawn). `kind` 0 field, 1 hero, 2 breather; `seed`
// 0..1 per star; `room` its direction.
void zs_storybook_star(inout vec3 tint, inout float bright, inout float size, float kind, float seed, vec3 room) {
  vec3 cream = vec3(1.0, 0.92, 0.74);
  tint = mix(tint, cream, 0.72);
  if (kind < 0.5) {
    // A select few are enlarged and brightened; the dust is hushed.
    float pick = fract(seed * 7.31);
    if (pick > 0.9) {
      bright *= 1.7;
      size *= 1.6;
    } else if (pick > 0.75) {
      bright *= 1.15;
      size *= 1.25;
    } else {
      bright *= 0.42;
      size *= 0.92;
    }
  } else {
    size *= 1.35;
  }
}

// Painted bands for the planet: a muted, harmonious set.
vec3 zs_storybook_pal(int i) {
  if (i == 0) return vec3(0.86, 0.58, 0.42);
  if (i == 1) return vec3(0.96, 0.88, 0.72);
  if (i == 2) return vec3(0.4, 0.6, 0.6);
  if (i == 3) return vec3(0.93, 0.74, 0.55);
  if (i == 4) return vec3(0.96, 0.88, 0.72);
  return vec3(0.3, 0.5, 0.54);
}

// The planet's body at a point: `p` the point on the unit sphere in the
// planet's own (slowly spinning) frame, `radial` its world normal, `view`
// the world direction to it from the eye, `sun` the sun's direction.
// rgb: display colour; a: how much shows by day (the night shows it whole).
vec4 zs_storybook_planet_body(vec3 p, vec3 radial, vec3 view, vec3 sun) {
  // Flat painted bands, their edges a little wavy and a hair soft.
  float lat = p.y + 0.035 * sin(atan(p.z, p.x) * 2.0 + p.y * 3.0);
  float t = lat * 4.2 + 12.0;
  float f = fract(t);
  int i = int(floor(t));
  float aa = max(fwidth(t), 0.0) + 0.035;
  vec3 a = zs_storybook_pal(i - (i / 6) * 6);
  int j = i + 1;
  vec3 b = zs_storybook_pal(j - (j / 6) * 6);
  vec3 base = mix(a, b, smoothstep(1.0 - aa, 1.0, f));
  // A thin pale line along each band's edge, like a pen's bead of paint.
  base += 0.04 * smoothstep(aa * 2.0, 0.0, f);
  // Simple shading: a soft terminator, a cool indigo shadow side.
  float diff = dot(radial, sun);
  float lit = smoothstep(-0.18, 0.3, diff);
  float ndv = max(dot(radial, -view), 0.0);
  vec3 shadow = base * vec3(0.34, 0.38, 0.6);
  vec3 sunny = base * mix(vec3(0.86, 0.84, 0.9), vec3(1.0, 0.97, 0.9), lit);
  vec3 col = mix(shadow, sunny, lit);
  col *= mix(0.82, 1.0, smoothstep(0.0, 0.5, ndv));
  col += vec3(1.0, 0.85, 0.65) * pow(1.0 - ndv, 4.0) * 0.22 * lit;
  return vec4(clamp(col, 0.0, 1.0), mix(0.7, 1.0, lit));
}

// The rings at a point: `local` the point in the ring plane (xz, in planet
// radii; the mesh spans radii 1.38 to 2.3), `fw` the screen footprint of a
// unit of radius, `lit` how squarely the sun strikes the ring plane, `shade`
// 1 in sunlight and 0 in the planet's shadow.
// rgb: display colour; a: density (opacity at night).
vec4 zs_storybook_planet_rings(vec3 local, float fw, float lit, float shade) {
  float r = length(local.xz);
  float e = max(fw, 0.002) * 1.2;
  // Three bold bands, two clean gaps, every edge antialiased by `fw`.
  float inner = smoothstep(1.4 - e, 1.4 + e, r) * (1.0 - smoothstep(1.64 - e, 1.64 + e, r));
  float mid = smoothstep(1.74 - e, 1.74 + e, r) * (1.0 - smoothstep(2.04 - e, 2.04 + e, r));
  float outer = smoothstep(2.11 - e, 2.11 + e, r) * (1.0 - smoothstep(2.28 - e, 2.28 + e, r));
  float density = inner * 0.78 + mid * 0.95 + outer * 0.6;
  vec3 c_in = vec3(0.86, 0.6, 0.44);
  vec3 c_mid = vec3(0.97, 0.89, 0.72);
  vec3 c_out = vec3(0.5, 0.68, 0.66);
  vec3 col = (c_in * inner + c_mid * mid + c_out * outer) / max(inner + mid + outer, 0.001);
  // A faint stroke within the middle band, so it is paint and not plastic.
  col *= 1.0 - 0.06 * smoothstep(1.86 - e, 1.86 + e, r) * (1.0 - smoothstep(1.9 - e, 1.9 + e, r));
  float sun = (0.55 + 0.45 * lit) * mix(0.22, 1.0, shade);
  col *= mix(vec3(0.3, 0.34, 0.55), vec3(1.0, 0.97, 0.92), sun);
  return vec4(col, density);
}

// The planet's glow round its disc, added: `x` the distance from its centre
// in planet radii (the card reaches 1.6), `side` 0..1 how far toward the sun.
vec3 zs_storybook_planet_glow(float x, float side) {
  if (x < 1.0) return vec3(0.0);
  float glow = exp(-(x - 1.0) / 0.12) * 0.35 + exp(-(x - 1.0) / 0.4) * 0.22;
  glow *= 1.0 - smoothstep(1.2, 1.6, x);
  return vec3(1.0, 0.8, 0.58) * glow * (0.35 + 0.65 * side) * 0.4;
}
#endif
