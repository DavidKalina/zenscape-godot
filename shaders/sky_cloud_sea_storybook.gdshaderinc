#ifndef ZS_SKY_CLOUD_SEA_STORYBOOK
#define ZS_SKY_CLOUD_SEA_STORYBOOK
// The Storybook cloud sea, as drawn on look/clouds-storybook (dbb8f95): one of the
// player's three cloud styles (shaders/sky_cloud_sea.gdshaderinc picks it by
// `cloud_sea_style`; scripts/look_pass.gd sets that). Kept as its branch drew
// it; only its names carry the style, so the three can live in one shader.
// Included by shaders/sky_cloud_sea.gdshaderinc under ZS_CLOUD_SEA_SHADE,
// after the shared veil (zs_sea_veil).
// Sculpted billows: the sea is a surface of cloud tops, not a haze. Its
// height is a field of round puffs (each lattice cell holds one, of its own
// size) on a slow heap-field that gathers them into heaps and opens a few
// gaps between. The view ray is marched a few steps into that surface, so
// near heaps stand over the ones behind. The light is soft and natural with
// only a breath of painted steps in it: a sunlit side, a cool lavender-blue
// shade, a short shadow cast toward the sun that fills the creases and a
// gentle lining where a heap's flank turns sunward. Through the gaps, far
// below and deep in blue air, lie glimpses of the world: fields, woods, low
// hills and now and then a river catching the sky.
#include "res://shaders/sky_sea_domes.gdshaderinc"
// The surface's height at `p` (sea units), 0 where the sea opens. `detail`
// fades the finest domes out where the pixel can't hold them.
float zs_storybook_sea_height(vec2 p, float detail) {
  // The heap-field: heaps where it is high, open sea where it is low.
  float mass = zs_storybook_sea_gnoise(p * 0.23 + vec2(3.1, 7.7)) * 0.7 + zs_storybook_sea_gnoise(p * 0.51 + vec2(8.3, 1.9)) * 0.3;
  float heap = smoothstep(-0.33, 0.22, mass);
  float h = zs_storybook_sea_domes(p) * 0.62 + zs_storybook_sea_domes(p * 2.17 + vec2(5.2, 1.3)) * 0.38 * detail;
  // Heaps swell from the field; their fringe sinks below the sea's floor.
  return max(h * (0.35 + 0.65 * heap) - (1.0 - heap) * 0.55, 0.0);
}
// The light on a heap: smooth and natural, with only a breath of the
// painted steps left in it, so the forms read without looking drawn.
float zs_storybook_sea_bands(float l, float w) {
  float smooth_l = smoothstep(0.0, 1.0, l);
  float soft = 0.16 + w;
  float steps = 0.5 * smoothstep(0.3 - soft, 0.3 + soft, l) + 0.5 * smoothstep(0.62 - soft, 0.62 + soft, l);
  return mix(smooth_l, steps, 0.25);
}
// The world far below, seen through a gap in the sea: fields and woods,
// low hills, now and then a river catching the sky; all of it deep in the
// haze, low in contrast, only a hint. `p` is in ground units, `foot` the
// pixel's footprint there.
vec3 zs_storybook_sea_ground(vec2 p, float foot, vec3 sky, float bright) {
  float hills = zs_storybook_sea_gnoise(p * 0.35 + vec2(2.7, 9.1)) * 0.6 + zs_storybook_sea_gnoise(p * 0.9 + vec2(5.3, 1.1)) * 0.4;
  float hx = zs_storybook_sea_gnoise((p + vec2(0.3, 0.0)) * 0.35 + vec2(2.7, 9.1)) * 0.6 + zs_storybook_sea_gnoise((p + vec2(0.3, 0.0)) * 0.9 + vec2(5.3, 1.1)) * 0.4;
  float fields = zs_storybook_sea_gnoise(p * 2.3 + vec2(11.0, 3.0));
  float woods = smoothstep(0.1, 0.35, zs_storybook_sea_gnoise(p * 1.1 + vec2(7.0, 13.0)));
  vec3 meadow = mix(vec3(0.5, 0.64, 0.46), vec3(0.62, 0.66, 0.5), smoothstep(-0.3, 0.3, fields) * (1.0 - smoothstep(0.4, 1.0, foot)));
  vec3 land = mix(meadow, vec3(0.36, 0.5, 0.44), woods);
  land = mix(land, vec3(0.5, 0.54, 0.58), smoothstep(0.2, 0.6, hills) * 0.5);
  // Slopes toward the light a little brighter.
  land *= 0.85 + 0.3 * clamp((hills - hx) * 3.0 + 0.5, 0.0, 1.0);
  // A river: a thin, wandering line where a slow field crosses zero.
  float wander = zs_storybook_sea_gnoise(p * 0.045 + vec2(31.0, 17.0)) + 0.12 * zs_storybook_sea_gnoise(p * 0.6 + vec2(3.0, 41.0));
  float river = 1.0 - smoothstep(0.003, 0.009 + foot * 0.01, abs(wander));
  land = mix(land, sky * 1.2 + 0.04, river * 0.35);
  return land * bright;
}

// The sea along `dir` (world) / `room` (the room's turn of it), premultiplied:
// rgb already times alpha. `horizon` is the sky's colour along the flattened
// direction, the haze it dissolves into; `below` the dome's own colour along
// `dir`. Both carry the sea's value, so the hour and the look carry it; the
// hues are the sea's own.
vec4 zs_cloud_sea_storybook(vec3 dir, vec3 room, vec3 horizon, vec3 below) {
  float veil = zs_sea_veil(dir);
  if (veil <= 0.0) return vec4(0.0);
  float down = max(-dir.y, 0.02);
  // Where the ray meets the sea's floor, in depths below the eye.
  vec2 at = room.xz / down;
  float far = length(at);
  float deep_night = zs_night * zs_celestial_clear;
  // Overcast: flatter light, softer bands, no lining.
  float dull = smoothstep(0.35, 0.9, zs_cloud.x);

  // Painted light: the sun's bearing, but always from a storybook angle, so
  // each heap keeps a lit and a shaded side whatever the hour.
  vec3 sun_room = zsRoomDir(zs_sun_direction);
  vec2 bearing = normalize(sun_room.xz + vec2(1e-4, 0.0));
  vec3 light = normalize(vec3(bearing.x, 0.62, bearing.y));

  vec3 sun_c = max(zs_cloud_sun, vec3(1e-4));
  vec3 sun_hue = sun_c / max(max(sun_c.r, sun_c.g), sun_c.b);
  vec3 base = mix(below, horizon, 0.2);
  float value = clamp(dot(base, vec3(0.3, 0.5, 0.2)) * 1.18, 0.0, 0.8);
  // Under a clear night the heaps keep a faint moonlit silver.
  value = max(value, deep_night * 0.1);
  // By day the heaps stay light, whatever the dome's own tone (a brown
  // desert dome made them mud); in the low warm sun they glow a little.
  float warm = clamp((sun_hue.r - sun_hue.b) * 1.6, 0.0, 1.0) * smoothstep(0.0, 0.25, zs_daylight) * (1.0 - dull);
  value = min(max(value, zs_daylight * mix(0.6, 0.5, dull)) * (1.0 + 0.22 * warm), 0.82);
  vec3 shade_hue = mix(vec3(0.8, 0.82, 1.0), vec3(0.84, 0.86, 0.93), dull);
  vec3 lit_col = value * mix(vec3(1.0), sun_hue, mix(0.5, 0.3, dull)) * mix(1.2, 1.0, dull);
  lit_col = mix(lit_col, value * vec3(0.92, 0.97, 1.08), deep_night * 0.6);
  vec3 mid_col = mix(value * mix(vec3(0.88, 0.9, 1.0), sun_hue, 0.3), horizon, 0.1);
  vec3 shade_col = mix(value * 0.86 * shade_hue, horizon * 0.86, 0.1 + 0.4 * dull);
  vec3 deep_air = mix(horizon, value * vec3(0.84, 0.88, 1.02), 0.45);

  // The near sea: its floor a depth below the eye, its heaps up to TALL
  // above that. Sea units: SCALE per depth.
  const float SCALE = 3.0;
  const float TALL = 0.2;
  vec2 drift = vec2(0.6, 0.35) * zs_motion_time * 0.004;
  vec3 ray = vec3(room.x, dir.y, room.z);
  float foot = length(fwidth(at)) * SCALE;
  float detail = 1.0 - smoothstep(0.25, 0.6, foot);
  // March from the heaps' tops to the floor.
  float t0 = (1.0 - TALL) / down;
  float t1 = 1.0 / down;
  const int STEPS = 12;
  float dt = (t1 - t0) / float(STEPS);
  float t = t0;
  float hit = -1.0;
  float prev_gap = TALL;
  for (int i = 0; i <= STEPS; i++) {
    vec3 pos = ray * t;
    float rise = zs_storybook_sea_height(pos.xz * SCALE + drift, detail);
    float gap = pos.y - (-1.0 + TALL * rise);
    // On the bare floor the ray has found a gap, not a heap.
    if (gap <= 0.0 && rise > 0.002) {
      // Between the last two steps: where the ray crossed.
      float k = prev_gap / max(prev_gap - gap, 1e-5);
      hit = t - dt * (1.0 - k);
      break;
    }
    prev_gap = gap;
    t += dt;
  }
  vec3 col;
  float rim_light = 0.0;
  if (hit > 0.0) {
    vec3 pos = ray * hit;
    vec2 q = pos.xz * SCALE + drift;
    float h = zs_storybook_sea_height(q, detail);
    // The surface's slope (in depths), and its normal.
    const float STEP = 0.08;
    float hx = zs_storybook_sea_height(q + vec2(STEP, 0.0), detail);
    float hz = zs_storybook_sea_height(q + vec2(0.0, STEP), detail);
    vec2 slope = vec2(hx - h, hz - h) / STEP * TALL * SCALE;
    vec3 n = normalize(vec3(-slope.x, 1.0, -slope.y));
    float l = dot(n, light) * 0.7 + 0.3;
    // A short shadow toward the sun: the creases and the far side of a heap
    // fall into the heap before it.
    float lit = 1.0;
    for (int s = 1; s <= 3; s++) {
      vec3 sp = pos + light * (TALL * 0.5 * float(s));
      float sh = -1.0 + TALL * zs_storybook_sea_height(sp.xz * SCALE + drift, detail);
      lit = min(lit, smoothstep(-0.02, 0.03, sp.y - sh));
    }
    // Far off, where the shadows would draw out into long scratches, they fade.
    lit = mix(1.0, lit, smoothstep(0.1, 0.32, down));
    l *= mix(0.72, 1.0, lit);
    float band = zs_storybook_sea_bands(l, foot * 0.3 + 0.03 * dull);
    col = mix(shade_col, mid_col, smoothstep(0.0, 0.5, band));
    col = mix(col, lit_col, smoothstep(0.5, 1.0, band));
    // Low in the creases the cloud is deeper in its own shade.
    col = mix(shade_col * 0.96, col, mix(0.82, 1.0, smoothstep(0.0, 0.45, h)));
    // The lining: an edge turned to the eye and the sun at once.
    // Steep, sunward sides of a heap: its rounded flank catching the light.
    float flank = smoothstep(0.25, 0.6, length(n.xz)) * smoothstep(0.2, 0.7, dot(normalize(n.xz + 1e-4), bearing));
    float edge = pow(1.0 - clamp(dot(n, -normalize(ray)), 0.0, 1.0), 2.0);
    rim_light = max(flank * 0.7, edge) * lit * (1.0 - dull);
    col = mix(col, lit_col * 1.1, rim_light * 0.3);
  }
  // Below the sea: the ground, far down (GROUND depths), seen through a thin
  // deeper veil of cloud and a great deal of air.
  const float GROUND = 6.0;
  vec2 gp = at * GROUND * 0.5;
  float gfoot = foot * GROUND * 0.5 / SCALE;
  // Aerial perspective: the deep air is cool and blue.
  vec3 air = mix(mix(deep_air, horizon, 0.2), value * vec3(0.74, 0.82, 0.95), 0.45 * (1.0 - dull) * (1.0 - 0.6 * warm));
  vec3 ground = zs_storybook_sea_ground(gp, gfoot, air, mix(0.12, value * 1.15, 0.85));
  vec3 gap_col = mix(ground, air, mix(0.42, 0.85, dull) + 0.3 * smoothstep(0.3, 0.08, down));
  // Wisps of the deeper sea drift over it.
  vec2 q2 = at * 1.7 * SCALE * 0.9 + drift * 0.6 + vec2(17.3, 4.1);
  float wisp = smoothstep(0.15, 0.7 + foot, zs_storybook_sea_height(q2, 0.0));
  gap_col = mix(gap_col, mix(mid_col, deep_air, 0.5), wisp * 0.45);
  if (hit > 0.0) {
    // The heaps' feet thin into the gap.
    vec3 pos = ray * hit;
    float h = zs_storybook_sea_height(pos.xz * SCALE + drift, detail);
    col = mix(gap_col, col, smoothstep(0.0, 0.1, h));
  } else {
    col = gap_col;
  }
  // Detail the pixel can no longer hold settles to the sea's mean.
  col = mix(col, mix(mid_col, deep_air, 0.4), smoothstep(0.5, 1.2, foot));
  // Air between the eye and the far sea: toward the horizon the heaps fade
  // into the sky's colour, where the ridges' misty feet stand.
  float haze = 1.0 - exp(-far * 0.09);
  haze = max(haze, smoothstep(-0.2, -0.03, dir.y));
  col = mix(col, horizon, haze * 0.85);
  return vec4(col * veil, veil);
}
#endif
