#ifndef ZS_NIGHT_OPAL
#define ZS_NIGHT_OPAL
// The Opal night sky: one of the player's night styles
// (shaders/night_sky.gdshaderinc picks it by zs_night_style; scripts/look_pass.gd
// sets that). The night companion to the Opal cloud sea: a luminous
// blue-violet-to-teal dome with a pearly horizon, a moonstone Milky Way
// whose billows carry a whisper of mother-of-pearl, and a pearl planet.
// Everything it paints is in this file, as pure functions of their arguments
// and the shader globals. Its names carry the style.
#include "res://shaders/night_noise.gdshaderinc"

// Mother-of-pearl: lilac, mint and peach, drifting with `t`, as pale tints
// near 1.0 that only ever whisper over a colour.
vec3 zs_opal_pearl(float t) {
  vec3 lilac = vec3(0.90, 0.80, 1.00);
  vec3 mint = vec3(0.78, 1.00, 0.94);
  vec3 peach = vec3(1.00, 0.86, 0.80);
  float a = 0.5 + 0.5 * sin(t * 6.2832);
  float b = 0.5 + 0.5 * sin(t * 6.2832 + 2.094);
  float c = 0.5 + 0.5 * sin(t * 6.2832 + 4.189);
  return (lilac * a + mint * b + peach * c) / (a + b + c + 1e-4);
}

// The dome at night: `col` is the sky's own colour along the direction, `y`
// the direction's height, `deep` how fully night and clear it is (0..1).
// Returns the dome's colour, before the Milky Way and the stars.
vec3 zs_opal_dome(vec3 col, float y, float deep) {
  // Blue-violet overhead, clearing to a luminous teal toward the horizon,
  // and a pearl glow lying along the horizon line itself.
  float up = smoothstep(0.0, 0.9, abs(y));
  float lift = exp(-abs(y) / 0.26);
  vec3 violet = vec3(0.040, 0.046, 0.140);
  vec3 teal = vec3(0.034, 0.140, 0.200);
  vec3 night = mix(teal, violet, pow(up, 0.7));
  night = mix(night, vec3(0.07, 0.12, 0.22), lift * 0.35);
  night = mix(night, col * 0.4, 0.15);
  float rim = exp(-abs(y) / 0.05);
  night += zs_opal_pearl(y * 1.6 + 0.1) * vec3(0.20, 0.20, 0.26) * rim * 0.30;
  night += vec3(0.05, 0.07, 0.10) * exp(-abs(y) / 0.20) * 0.30;
  return mix(col, night, deep);
}

// The sky's painted night light along the room direction `room` (the Milky
// Way, and whatever veils the style hangs): display colour, which the dome
// scales by how much the stars show. `pixel` is radians per screen pixel.
vec3 zs_opal_light(vec3 room, float pixel) {
  vec3 light = vec3(0.0);
  // A few very faint pastel veils, rare and slow: one low noise decides
  // where they live, and only there are two octaves spent.
  float t = zs_motion_time * 0.0012;
  vec3 vp = room * 1.35 + vec3(t, 0.0, -t * 0.7);
  float gate = zs_night_noise(vp + 4.0);
  if (gate > 0.18) {
    float body = zs_night_fbm(room * 2.6 + vec3(2.0, -t, 5.0), 2, pixel * 2.6);
    float veil = smoothstep(0.18, 0.62, gate) * smoothstep(0.42, 0.78, body);
    light += zs_opal_pearl(gate * 0.8 + body * 0.6) * vec3(0.20, 0.22, 0.34) * veil * 0.20;
  }
  // The band: a tilted great circle.
  vec3 n = normalize(vec3(0.6, 0.25, 0.75));
  float d = dot(room, n);
  if (abs(d) > 0.5) return light;
  vec3 centre = normalize(cross(n, vec3(0.0, 1.0, 0.0)));
  float core = pow(max(dot(room, centre), 0.0), 2.0);
  vec2 w = vec2(zs_night_noise(room * 2.2 + 1.3), zs_night_noise(room * 2.2 + 7.1));
  float off = d + w.x * 0.12 + w.y * 0.05;
  float width = mix(0.11, 0.20, core);
  float band = exp(-off * off / (width * width));
  if (band < 0.01) return light;
  // The detail is stretched along the band, so billows and dust lie in it
  // like drifts of cloud rather than blots.
  vec3 tang = cross(n, centre);
  vec3 q = room - (centre * dot(room, centre) + tang * dot(room, tang)) * 0.62;
  q += vec3(w, 0.0) * 0.35;
  float billow = zs_night_fbm(q * 3.4, 3, pixel * 3.4);
  float glow = band * mix(0.28, 1.0, smoothstep(0.30, 0.76, billow * 0.85 + band * 0.3));
  // Gentle dark lanes: thin, soft dust along the core.
  float dust = zs_night_fbm(q * 5.0 + 5.0, 3, pixel * 5.0);
  float lanes = smoothstep(0.52, 0.72, dust) * exp(-off * off / (width * width * 0.5));
  // Moonstone: pale blue-grey haze with pearl in the billows, and a
  // whisper of lilac, mint and peach shifting along the band.
  vec3 moon = vec3(0.26, 0.27, 0.40);
  vec3 pearl = zs_opal_pearl(billow * 1.1 + off * 2.0 + dot(room, tang) * 0.5);
  vec3 tone = mix(vec3(0.30, 0.30, 0.40), vec3(0.50, 0.45, 0.56), core * 0.6 + 0.4 * smoothstep(0.5, 0.8, billow));
  tone = mix(tone, tone * pearl * 1.2, 0.45);
  vec3 haze = moon * band * 0.17;
  light += (haze + tone * glow * 0.27) * (1.0 - 0.55 * lanes);
  return light;
}

// A star as the style sees it (shaders/sky_stars.gdshader): `tint` its
// colour, `bright` its brightness (a hero's is HDR power), `size` a scale
// on its width (1 as drawn). `kind` 0 field, 1 hero, 2 breather; `seed`
// 0..1 per star; `room` its direction.
void zs_opal_star(inout vec3 tint, inout float bright, inout float size, float kind, float seed, vec3 room) {
  // Toward pearl and pastel: a quarter of the way to a pale tint.
  vec3 pale = zs_opal_pearl(seed * 3.0);
  tint = mix(tint, pale * 1.0, 0.22);
}

// How much of the planet's disc a pixel covers at its limb: fades the edge
// over about a pixel, so the silhouette is clean and antialiased.
float zs_opal_planet_edge(vec3 radial, vec3 view) {
  float c = clamp(dot(radial, -view), 0.0, 1.0);
  float s = sqrt(1.0 - c * c);
  float fw = max(fwidth(s), 1e-5);
  return clamp((1.0 - s) / fw + 0.5, 0.0, 1.0);
}

// The planet's body at a point: `p` the point on the unit sphere in the
// planet's own (slowly spinning) frame, `radial` its world normal, `view`
// the world direction to it from the eye, `sun` the sun's direction.
// rgb: display colour; a: how much shows by day (the night shows it whole).
vec4 zs_opal_planet_body(vec3 p, vec3 radial, vec3 view, vec3 sun) {
  float lit = smoothstep(-0.25, 0.9, dot(radial, sun));
  // Milky bands, bent by slow noise, with finer lanes laid between.
  float lat = p.y + 0.05 * zs_night_noise(p * 2.0 + 3.0) + 0.025 * zs_night_noise(p * 4.5 + 9.0);
  float wide = 0.5 + 0.5 * sin(lat * 9.0 + 0.8 * zs_night_noise(p * 1.5));
  float fine = 0.5 + 0.5 * zs_night_noise(vec3(lat * 26.0, 1.7, 4.2));
  vec3 pearl = vec3(0.92, 0.90, 0.95);
  vec3 lilac = vec3(0.76, 0.72, 0.88);
  vec3 blush = vec3(0.94, 0.82, 0.84);
  vec3 mint = vec3(0.78, 0.90, 0.88);
  vec3 base = mix(pearl, lilac, smoothstep(0.2, 0.9, wide) * 0.8);
  base = mix(base, blush, smoothstep(0.55, 0.95, 0.5 + 0.5 * sin(lat * 5.0 + 2.0)) * 0.45);
  base = mix(base, mint, smoothstep(0.7, 1.0, 0.5 + 0.5 * sin(lat * 7.0 - 1.0)) * 0.35);
  base = mix(base, base * 0.90, (fine - 0.5) * 0.7);
  // Lit from within as much as from the sun: a milky glow, softly shaded.
  float cosv = max(dot(radial, -view), 0.0);
  float shade = 0.34 + 0.66 * lit;
  vec3 col = base * shade;
  col *= mix(0.78, 1.0, smoothstep(0.0, 0.7, cosv));
  // The opal sheen: pastel hues sliding with the angle near the limb.
  float limb = pow(1.0 - cosv, 2.4);
  vec3 sheen = zs_opal_pearl(cosv * 0.9 + p.y * 0.25 + 0.1);
  col = mix(col, sheen * 0.95, limb * 0.5);
  col += vec3(0.20, 0.24, 0.34) * limb * 0.25;
  return vec4(clamp(col, 0.0, 1.0), max(lit, limb * 0.6) * 0.5);
}

// The rings at a point: `local` the point in the ring plane (xz, in planet
// radii; the mesh spans radii 1.38 to 2.3), `fw` the screen footprint of a
// unit of radius, `lit` how squarely the sun strikes the ring plane, `shade`
// 1 in sunlight and 0 in the planet's shadow.
// rgb: display colour; a: density (opacity at night).
vec4 zs_opal_planet_rings(vec3 local, float fw, float lit, float shade) {
  float r = length(local.xz);
  float keep = 1.0 - smoothstep(0.02, 0.07, fw);
  // Fine lanes: three scales of one-dimensional noise, fading as they
  // near a pixel.
  float l1 = zs_night_noise(vec3(r * 9.0, 2.3, 0.7));
  float l2 = zs_night_noise(vec3(r * 31.0, 5.1, 1.9)) * (1.0 - smoothstep(0.015, 0.05, fw));
  float l3 = zs_night_noise(vec3(r * 90.0, 8.4, 3.3)) * keep * (1.0 - smoothstep(0.006, 0.02, fw));
  float lanes = clamp(0.62 + 0.20 * l1 + 0.16 * l2 + 0.10 * l3, 0.0, 1.0);
  float gap = 1.0 - 0.80 * exp(-pow((r - 1.86) / 0.045, 2.0));
  gap *= 1.0 - 0.35 * exp(-pow((r - 2.08) / 0.02, 2.0));
  float density = smoothstep(1.38, 1.52, r) * (1.0 - smoothstep(2.12, 2.3, r)) * lanes * gap;
  float light = (0.30 + 0.70 * lit) * mix(0.10, 1.0, shade);
  vec3 dust = mix(vec3(0.88, 0.84, 0.90), vec3(0.80, 0.78, 0.90), smoothstep(1.4, 2.2, r));
  // A faint iridescence, sliding with the radius.
  dust = mix(dust, dust * zs_opal_pearl(r * 1.2 + l1 * 0.2) * 1.12, 0.35);
  return vec4(dust * (0.07 + 0.85 * light), density * 0.62);
}

// The planet's glow round its disc, added: `x` the distance from its centre
// in planet radii (the card reaches 1.6), `side` 0..1 how far toward the sun.
vec3 zs_opal_planet_glow(float x, float side) {
  float glow = x > 1.0 ? exp(-(x - 1.0) / 0.12) * 0.7 + exp(-(x - 1.0) / 0.4) * 0.3 : pow(x, 8.0) * 0.4;
  glow *= 1.0 - smoothstep(1.28, 1.6, x);
  vec3 tint = mix(vec3(0.62, 0.66, 0.95), vec3(0.85, 0.74, 0.95), smoothstep(1.0, 1.4, x));
  return tint * glow * (0.25 + 0.75 * side) * 0.30;
}
#endif
