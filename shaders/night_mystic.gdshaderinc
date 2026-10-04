#ifndef ZS_NIGHT_MYSTIC
#define ZS_NIGHT_MYSTIC
// The Mystic night sky: one of the player's night styles
// (shaders/night_sky.gdshaderinc picks it by zs_night_style; scripts/look_pass.gd
// sets that). The dreamlike one: a dim violet-teal dome, faint aurora-like
// veils drifting low, a silvery-violet Milky Way with nebula wisps woven
// through it, a few slow-breathing stars, and a pale otherworldly planet.
// Everything it paints is in this file, as pure functions of their arguments
// and the shader globals, so the dome, the stars and the planet can each
// include it. Its names carry the style. All its motion is slow: tens of
// seconds a turn, on zs_motion_time.
#include "res://shaders/night_noise.gdshaderinc"

// The dome at night: `col` is the sky's own colour along the direction, `y`
// the direction's height, `deep` how fully night and clear it is (0..1).
// Returns the dome's colour, before the Milky Way and the stars.
vec3 zs_mystic_dome(vec3 col, float y, float deep) {
  // Violet overhead, easing to teal at the horizon line and a little below.
  float lift = exp(-abs(y) / 0.3);
  vec3 violet = vec3(0.034, 0.026, 0.085);
  vec3 teal = vec3(0.022, 0.082, 0.112);
  vec3 night = mix(violet, teal, lift);
  // A breath of lighter teal air hugging the horizon line.
  night += vec3(0.012, 0.045, 0.045) * exp(-abs(y) / 0.05);
  // Keep a little of the look's own sky, so moods still tint it.
  night = mix(night, col * 0.35, 0.15);
  return mix(col, night, deep);
}

// A point on a circle about the vertical, for noise that closes on itself:
// sampled round a circle of radius `k`, an azimuth never has a seam.
vec3 zs_mystic_ring(vec3 room, float k, float h, float t) {
  vec2 d = normalize(room.xz + 1e-6) * k;
  return vec3(d.x + t * 0.3, d.y - t * 0.2, h);
}

// One veil: a drifting curtain whose foot hangs at a wandering height, with
// soft vertical rays. `seed` sets it apart from its sister, `pixel` is
// radians per pixel. Returns 0..1 brightness; `hue` 0 teal to 1 violet.
float zs_mystic_veil(vec3 room, float seed, float pixel, float t, out float hue) {
  float h = room.y;
  vec3 c1 = zs_mystic_ring(room, 1.1, seed, t * 0.01);
  float foot = 0.04 + 0.12 * zs_night_noise(c1) + 0.07 * seed;
  float v = h - foot;
  hue = 0.5 + 0.5 * zs_night_noise(zs_mystic_ring(room, 0.8, seed + 4.0, t * 0.008));
  if (v < -0.04 || v > 0.7) return 0.0;
  // Body: bright just above the foot, thinning upward; the foot itself soft.
  float body = smoothstep(-0.04, 0.05, v) * exp(-max(v, 0.0) / (0.16 + 0.06 * hue));
  // Soft vertical rays: noise stretched up the sky, fading to its mean
  // where it would be finer than a pixel.
  float fine_keep = 1.0 - smoothstep(0.3, 0.9, pixel * 26.0);
  float ray = 0.5 + 0.5 * zs_night_noise(zs_mystic_ring(room, 26.0, seed * 3.0 + v * 0.9, t * 0.02)) * fine_keep;
  float ray2 = 0.5 + 0.5 * zs_night_noise(zs_mystic_ring(room, 9.0, seed * 5.0 + v * 0.4 + 3.0, -t * 0.012));
  float rays = mix(0.55, 1.0, clamp(ray * ray2 * 1.6, 0.0, 1.0));
  // Where the curtain hangs at all: patches, so some sky stays clear.
  float patch = smoothstep(-0.25, 0.45, zs_night_noise(zs_mystic_ring(room, 0.9, seed + 11.0, t * 0.006)));
  return body * rays * patch;
}

// The sky's painted night light along the room direction `room` (the Milky
// Way, and whatever veils the style hangs): display colour, which the dome
// scales by how much the stars show. `pixel` is radians per screen pixel.
vec3 zs_mystic_light(vec3 room, float pixel) {
  vec3 sum = vec3(0.0);
  float t = zs_motion_time;
  // The veils: teal and violet curtains, low and gauzy.
  if (room.y > -0.06 && room.y < 0.75) {
    float hue1;
    float v1 = zs_mystic_veil(room, 0.0, pixel, t, hue1);
    float hue2;
    float v2 = zs_mystic_veil(room, 1.7, pixel, t * 0.8 + 40.0, hue2);
    vec3 teal = vec3(0.12, 0.62, 0.55);
    vec3 violet = vec3(0.45, 0.26, 0.78);
    vec3 low = vec3(0.16, 0.7, 0.62);
    sum += mix(teal, violet, hue1) * v1 * 0.09;
    sum += mix(violet, low, hue2 * 0.8) * v2 * 0.07;
  }
  // The Milky Way: a silvery-violet river.
  vec3 n = normalize(vec3(0.6, 0.25, 0.75));
  float d = dot(room, n);
  if (abs(d) > 0.5) return sum;
  vec3 centre = normalize(cross(n, vec3(0.0, 1.0, 0.0)));
  float core = pow(max(dot(room, centre), 0.0), 2.0);
  vec3 w = vec3(zs_night_noise(room * 2.5 + 1.3), zs_night_noise(room * 2.5 + 7.1), 0.0) * 0.5;
  float off = d + w.x * 0.14 + w.y * 0.05;
  float width = mix(0.12, 0.2, core);
  float band = exp(-off * off / (width * width));
  if (band < 0.01) return sum;
  float billow = zs_night_fbm(room * 3.5 + w * 1.6, 4, pixel * 3.5);
  float glow = band * mix(0.3, 1.0, smoothstep(0.25, 0.8, billow * 0.8 + band * 0.35));
  float ridge = 1.0 - abs(zs_night_fbm(room * 5.0 + w * 2.2 + 5.0, 3, pixel * 5.0) * 2.0 - 1.0);
  float lanes = smoothstep(0.78, 0.95, ridge) * exp(-off * off / (width * width * 0.35));
  vec3 silver = mix(vec3(0.5, 0.52, 0.78), vec3(0.78, 0.76, 0.95), core * 0.7 + 0.3 * smoothstep(0.55, 0.85, billow));
  vec3 haze = vec3(0.07, 0.07, 0.15) * band;
  // Nebula wisps woven through: thin ridged filaments in teal and violet,
  // slowly drifting, strongest where the river is.
  vec3 wp = room * 4.2 + w * 2.0 + vec3(t * 0.004, 0.0, -t * 0.003);
  float wisp = 1.0 - abs(zs_night_fbm(wp, 2, pixel * 4.2) * 2.0 - 1.0);
  wisp = smoothstep(0.62, 0.97, wisp) * smoothstep(0.3, 0.7, billow) * band;
  float wh = zs_night_noise01(room * 1.7 + 9.0);
  vec3 wisp_col = mix(vec3(0.16, 0.58, 0.62), vec3(0.52, 0.3, 0.8), wh);
  vec3 mw = (haze * 0.4 + silver * glow * 0.3) * (1.0 - 0.8 * lanes) + wisp_col * wisp * 0.22;
  return sum + mw;
}

// A star as the style sees it (shaders/sky_stars.gdshader): `tint` its
// colour, `bright` its brightness (a hero's is HDR power), `size` a scale
// on its width (1 as drawn). `kind` 0 field, 1 hero, 2 breather; `seed`
// 0..1 per star; `room` its direction.
void zs_mystic_star(inout vec3 tint, inout float bright, inout float size, float kind, float seed, vec3 room) {
  float t = zs_motion_time;
  // Cool the whole field a touch toward silver-lavender.
  tint = mix(tint, vec3(0.82, 0.86, 1.0), 0.25);
  // A rare few take a slow colour breath, teal to violet, over a minute.
  if (kind < 1.5 && fract(seed * 37.0) < 0.07) {
    float b = 0.5 + 0.5 * sin(t * (0.09 + 0.04 * fract(seed * 91.0)) + seed * 60.0);
    vec3 hue = mix(vec3(0.5, 1.0, 0.9), vec3(0.78, 0.6, 1.0), b);
    tint = mix(tint, hue, 0.6);
    bright *= 0.85 + 0.25 * b;
  }
}

// The planet's body at a point: `p` the point on the unit sphere in the
// planet's own (slowly spinning) frame, `radial` its world normal, `view`
// the world direction to it from the eye, `sun` the sun's direction.
// rgb: display colour; a: how much shows by day (the night shows it whole).
vec4 zs_mystic_planet_body(vec3 p, vec3 radial, vec3 view, vec3 sun) {
  float t = zs_motion_time;
  float ndv = max(dot(radial, -view), 0.0);
  // Gentle swirling bands: latitude bent by slow low-frequency noise.
  float bend = zs_night_noise(p * 2.2 + vec3(0.0, t * 0.004, 0.0)) * 0.22
             + zs_night_noise(p * 4.6 + 3.7) * 0.07;
  float lat = p.y + bend;
  float band = 0.5 + 0.5 * sin(lat * 9.0 + 1.2 * sin(lat * 3.0 + 0.6));
  float fine = 0.5 + 0.5 * sin(lat * 27.0 + bend * 9.0);
  float storm = smoothstep(0.35, 0.8, zs_night_noise01(p * 3.1 + vec3(5.0, t * 0.003, 0.0)));
  vec3 lavender = vec3(0.62, 0.55, 0.88);
  vec3 teal = vec3(0.34, 0.68, 0.74);
  vec3 silver = vec3(0.86, 0.88, 0.97);
  vec3 base = mix(lavender, silver, smoothstep(0.2, 0.9, band));
  base = mix(base, teal, smoothstep(0.55, 1.0, 1.0 - band) * 0.55 * (0.5 + 0.5 * storm));
  base *= 0.9 + 0.1 * fine;
  // Light: the sun's side, but it glows from within, so the dark side holds
  // a dim lavender rather than going out.
  float lit = smoothstep(-0.3, 0.9, dot(radial, sun));
  vec3 col = base * mix(0.34, 1.0, lit);
  // The dark side takes cooler, bluer tones.
  col = mix(col * vec3(0.8, 0.9, 1.1), col, lit);
  // A soft limb: a touch dimmer toward the edge of the face, with a thin
  // glowing teal-lavender atmosphere rim climbing the edge.
  float edge = 1.0 - ndv;
  col *= mix(1.0, 0.8, smoothstep(0.4, 1.0, edge));
  float rim = pow(edge, 4.0);
  col += mix(vec3(0.3, 0.8, 0.85), vec3(0.65, 0.6, 1.0), 0.5 + 0.5 * p.y) * rim * 0.5;
  // A clean antialiased limb: ndv squared falls to 0 at the edge, and over
  // a pixel there it is as wide as its own screen derivative.
  float e = ndv * ndv;
  float aa = clamp(e / max(fwidth(e), 1e-5), 0.0, 1.0);
  return vec4(clamp(col, 0.0, 1.0), mix(0.12, 1.0, lit) * 0.5 * aa);
}

// The rings at a point: `local` the point in the ring plane (xz, in planet
// radii; the mesh spans radii 1.38 to 2.3), `fw` the screen footprint of a
// unit of radius, `lit` how squarely the sun strikes the ring plane, `shade`
// 1 in sunlight and 0 in the planet's shadow.
// rgb: display colour; a: density (opacity at night).
vec4 zs_mystic_planet_rings(vec3 local, float fw, float lit, float shade) {
  float r = length(local.xz);
  // Lanes fade to their mean where they are finer than a pixel.
  float keep = 1.0 - smoothstep(0.015, 0.05, fw);
  float coarse = 0.5 + 0.5 * zs_night_noise(vec3(r * 9.0, 1.3, 0.0));
  float fine = zs_night_noise(vec3(r * 52.0, 4.1, 2.0)) * keep;
  float hair = zs_night_noise(vec3(r * 130.0, 7.7, 5.0)) * (1.0 - smoothstep(0.006, 0.02, fw));
  float lanes = clamp(0.35 + 0.5 * coarse + 0.22 * fine + 0.1 * hair, 0.0, 1.0);
  // A wide gap and a thin one.
  float gap = 1.0 - 0.9 * exp(-pow((r - 1.84) / 0.035, 2.0)) - 0.5 * exp(-pow((r - 2.02) / 0.012, 2.0));
  float density = smoothstep(1.38, 1.5, r) * (1.0 - smoothstep(2.12, 2.3, r)) * lanes * gap;
  // Lit faintly from within: lavender nearer in, teal and silver outward.
  vec3 col = mix(vec3(0.7, 0.62, 0.95), vec3(0.5, 0.82, 0.86), smoothstep(1.4, 2.25, r));
  col = mix(col, vec3(0.92, 0.92, 1.0), 0.25 * coarse);
  // The shadow is soft-edged, and the rings' own glow keeps it from black.
  float light = (0.55 + 0.25 * lit) * mix(0.28, 1.0, smoothstep(0.0, 1.0, shade));
  return vec4(col * light, density * 0.55);
}

// The planet's glow round its disc, added: `x` the distance from its centre
// in planet radii (the card reaches 1.6), `side` 0..1 how far toward the sun.
vec3 zs_mystic_planet_glow(float x, float side) {
  // A thin bright atmosphere rim just past the limb, then a faint halo.
  float rim = x > 1.0 ? exp(-(x - 1.0) / 0.025) : pow(x, 24.0);
  float halo = x > 1.0 ? exp(-(x - 1.0) / 0.22) : 0.0;
  float glow = rim * 0.35 + halo * 0.12;
  glow *= 1.0 - smoothstep(1.3, 1.6, x);
  vec3 tint = mix(vec3(0.4, 0.8, 0.9), vec3(0.7, 0.6, 1.0), smoothstep(1.0, 1.35, x));
  return tint * glow * (0.6 + 0.4 * side) * 0.6;
}
#endif
