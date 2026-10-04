#ifndef ZS_SKY_CLOUD_SEA_MYSTIC
#define ZS_SKY_CLOUD_SEA_MYSTIC
// The Mystic cloud sea, as drawn on look/clouds-mystic (65d9a5c): one of the
// player's three cloud styles (shaders/sky_cloud_sea.gdshaderinc picks it by
// `cloud_sea_style`; scripts/look_pass.gd sets that). Kept as its branch drew
// it; only its names carry the style, so the three can live in one shader.
// Included by shaders/sky_cloud_sea.gdshaderinc under ZS_CLOUD_SEA_SHADE,
// after the shared veil (zs_sea_veil).
float zs_mystic_sea_hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float zs_mystic_sea_noise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(zs_mystic_sea_hash(i), zs_mystic_sea_hash(i + vec2(1.0, 0.0)), f.x),
             mix(zs_mystic_sea_hash(i + vec2(0.0, 1.0)), zs_mystic_sea_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
// Rounded billows: value noise whose finer octaves fade out where they
// would shimmer (`blur` is the pattern's footprint per pixel), so the far
// sea goes smooth instead of crawling.
float zs_mystic_sea_billows(vec2 q, float blur) {
  float h = 0.0;
  float amp = 0.5;
  float freq = 1.0;
  float total = 0.0;
  for (int o = 0; o < 4; o++) {
    float keep = 1.0 - smoothstep(0.25, 0.7, blur * freq);
    h += zs_mystic_sea_noise(q * freq + vec2(float(o) * 7.3, float(o) * 3.1)) * amp * keep + 0.5 * amp * (1.0 - keep);
    total += amp;
    freq *= 2.07;
    amp *= 0.5;
  }
  return h / total;
}
float zs_mystic_sea_luma(vec3 c) {
  return dot(c, vec3(0.2126, 0.7152, 0.0722));
}
// A colour's hue at unit luminance.
vec3 zs_mystic_sea_hue(vec3 c) {
  return max(c, vec3(0.0)) / max(zs_mystic_sea_luma(c), 1e-4);
}

// Shafts of light falling past the plate into the depths: soft beams that
// converge, as sunbeams do, on the point opposite the sun (pulled toward
// straight down, so they always fall into the sea). Seen from above they
// fan out of the deep. 0..1, already faded with distance.
float zs_mystic_sea_shafts(vec3 dir) {
  vec3 v = normalize(mix(-zs_sun_direction, vec3(0.0, -1.0, 0.0), 0.45));
  vec3 t1 = normalize(cross(v, vec3(1.0, 0.0, 0.0)));
  vec3 t2 = cross(v, t1);
  float away = acos(clamp(dot(dir, v), -1.0, 1.0));
  float fade = smoothstep(0.06, 0.4, away) * (1.0 - smoothstep(0.8, 1.55, away));
  if (fade <= 0.0) return 0.0;
  float ang = atan(dot(dir, t2), dot(dir, t1));
  // Round the circle in noise space, so the beams have no seam; they drift
  // round very slowly, as the gaps they fall through would.
  vec2 ring = vec2(cos(ang), sin(ang));
  float t = zs_motion_time * 0.006;
  float n = zs_mystic_sea_noise(ring * 6.5 + vec2(t, 1.7)) * 0.65
    + zs_mystic_sea_noise(ring * 14.0 + vec2(3.1, t * 1.6)) * 0.35;
  return smoothstep(0.55, 0.82, n) * fade;
}

// The land far below the sea, glimpsed through its deeper gaps: a world
// under the plate, so it feels high above somewhere real. Fields of green,
// olive and slate under broad hill shading, and now and then a thread of
// river catching the sky. `g` is the ground, in sea depths, where the ray
// meets it; `blur` its footprint per pixel, past which it melts to an even
// tone. Returns the land's colour at unit light (rgb) and its river (a).
vec4 zs_mystic_sea_ground(vec2 g, float blur) {
  float detail = 1.0 - smoothstep(0.08, 0.3, blur);
  float field = zs_mystic_sea_noise(g * 2.2);
  float hills = zs_mystic_sea_noise(g * 0.55 + 7.0);
  vec3 land = mix(vec3(0.4, 0.58, 0.36), vec3(0.62, 0.6, 0.42), smoothstep(0.35, 0.65, field));
  land = mix(land, vec3(0.48, 0.54, 0.6), smoothstep(0.6, 0.85, zs_mystic_sea_noise(g * 1.3 + 4.1)));
  land = mix(vec3(0.53, 0.58, 0.48), land, detail);
  land *= mix(0.85, 1.1, hills);
  float bend = zs_mystic_sea_noise(g * 0.4 + 2.3) + 0.3 * zs_mystic_sea_noise(g * 2.4 + 8.8);
  float river = (1.0 - smoothstep(0.006, 0.016, abs(bend - 0.66))) * detail;
  return vec4(land, river);
}

// The sea along `dir` (world) / `room` (the room's turn of it), premultiplied:
// rgb already times alpha. `horizon` is the sky's colour along the flattened
// direction, the haze it dissolves into; `below` the dome's own colour along
// `dir`, which the sea keeps as its tone so the backdrop stays the look's.
//
// Kept quiet: beautiful clean cloud first. By day the billows are cleaned
// toward the sky's own colour and the sun's white, away from the warm
// horizon glow that read as dusty beige. Through the deeper gaps the land
// shows far below, hazed nearly away. Soft light falls past the plate into
// the gaps, and a very faint light rises from the deep.
vec4 zs_cloud_sea_mystic(vec3 dir, vec3 room, vec3 horizon, vec3 below) {
  float veil = zs_sea_veil(dir);
  if (veil <= 0.0) return vec4(0.0);
  float down = max(-dir.y, 0.02);
  // Where the ray meets the sea, in depths below the eye.
  vec2 at = room.xz / down;
  float far = length(at);
  float t = zs_motion_time;
  // Broad billows, drifting slowly, their outlines rounded by a slow warp
  // so they swell as cloud does instead of lying as a noise field.
  vec2 q = at * 1.4 + vec2(0.6, 0.35) * t * 0.004;
  vec2 warp = vec2(zs_mystic_sea_noise(q * 0.45 + 3.7), zs_mystic_sea_noise(q * 0.45 + 9.2)) - 0.5;
  q += warp * 0.9;
  float blur = length(fwidth(q));
  float h = clamp((zs_mystic_sea_billows(q, blur) - 0.5) * 1.5 + 0.5, 0.0, 1.0);
  // The side of each billow that faces the sun, by a step toward it.
  vec3 sun_room = zsRoomDir(zs_sun_direction);
  vec2 toward = normalize(sun_room.xz + 1e-4);
  float ahead = clamp((zs_mystic_sea_billows(q + toward * 0.08, blur) - 0.5) * 1.5 + 0.5, 0.0, 1.0);
  float lit = clamp((h - ahead) * 7.0 + 0.5, 0.0, 1.0);
  // Mostly one sea, with clear troughs between the billows; the edges firm
  // up where the pattern is resolved and soften where it blurs. The crowns
  // stand highest and brightest.
  float firm = 1.0 - smoothstep(0.15, 0.6, blur);
  float cover = smoothstep(mix(0.3, 0.4, firm), mix(0.7, 0.58, firm), h);
  float crown = smoothstep(0.55, 0.9, h);
  // Calm overcast: flatter light, less relief.
  float overcast = smoothstep(0.35, 0.9, zs_cloud.x);
  float relief = mix(1.0, 0.5, overcast);
  // Air between the eye and the far sea: the tone lifts toward the
  // horizon's glow and the billows fade into it.
  float haze = 1.0 - exp(-far * 0.3);
  float near = 1.0 - haze;

  // How much of the day's cleaning applies: full with the sun well up,
  // none by golden hour, whose warm peach sea is the look.
  float day = smoothstep(0.1, 0.32, zs_sun_direction.y) * (1.0 - zs_night) * (1.0 - 0.6 * overcast);
  float night = zs_night * zs_celestial_clear;
  vec3 tone = mix(below, horizon, haze);
  float lum = zs_mystic_sea_luma(tone);
  // Only a dusty tone is cleaned: warm and greyed, as the default look's
  // beige was. The authored looks with a clear colour of their own (teal
  // mist, desert amber, rose dusk) keep it. The hue it cleans toward is
  // mostly the upper sky's.
  float tone_max = max(tone.r, max(tone.g, tone.b));
  float tone_sat = (tone_max - min(tone.r, min(tone.g, tone.b))) / max(tone_max, 1e-4);
  float dusty = smoothstep(0.0, 0.08, (tone.r - tone.b) / max(tone_max, 1e-4)) * (1.0 - smoothstep(0.28, 0.5, tone_sat));
  float clean = day * dusty;
  vec3 sky_hue = mix(zs_mystic_sea_hue(tone), zs_mystic_sea_hue(zs_sky_up), 0.8);
  vec3 sun_hue = zs_mystic_sea_hue(zs_cloud_sun);
  // Bodies shade from their sides up to their crowns, a little brighter on
  // the sun's side; the troughs between them fall deeper.
  float shade = mix(0.5, crown * 0.6 + lit * 0.4, relief);
  float form = (0.3 + 0.7 * near) * relief;
  // Golden hour and night: the dome's own tone, its warm haze kept (the
  // peach sea is the look), with gentle relief.
  vec3 trough = tone * 0.8;
  vec3 body = tone * mix(0.84, 1.12, shade);
  vec3 col = mix(tone, mix(trough, body, cover), form * 0.6);
  // By day: pastel, not dusty. Cream on the crowns, a soft lavender on the
  // shaded flanks, periwinkle depths, and a pale pearl haze far off.
  vec3 lavender = mix(vec3(1.0), sky_hue * vec3(1.06, 0.95, 0.98), 0.4);
  vec3 cream = mix(vec3(1.0), sun_hue, 0.4);
  vec3 pearl = mix(vec3(1.0), sky_hue, 0.12);
  vec3 day_body = lum * mix(0.8 * lavender, 1.08 * cream, shade);
  vec3 day_trough = lum * 0.64 * mix(vec3(1.0), sky_hue * vec3(1.06, 0.95, 1.0), 0.5);
  vec3 day_col = mix(lum * 0.96 * pearl, mix(day_trough, day_body, cover), form);
  col = mix(col, day_col, clean);
  vec3 depths = mix(trough, day_trough, clean);
  // Sunlit tops take the deck's sun colour (the moon's at night, a little
  // stronger, so the sea under the stars still reads), whiter by day.
  vec3 sun_light = mix(zs_cloud_sun, lum * cream * 3.0, day * 0.6);
  col += sun_light * cover * lit * crown * relief * mix(0.25, 1.0, near) * mix(0.07, 0.12, night);

  // The land far below, through the deeper gaps only: it lies three sea
  // depths further down, so it slides under the gaps as the view turns.
  // Lit as the sea is, and hazed most of the way into the gap's own air.
  float gap = smoothstep(0.36, 0.14, h) * (1.0 - smoothstep(1.2, 3.5, far)) * (1.0 - night) * relief;
  if (gap > 0.001) {
    vec2 g = at * 4.0 + vec2(23.0, 7.0);
    vec4 land = zs_mystic_sea_ground(g * 0.5, blur * 1.4);
    vec3 lit_land = land.rgb * lum * mix(vec3(1.0), sun_hue, 0.3) * 0.95;
    lit_land = mix(lit_land, lum * 1.15 * mix(vec3(1.0), sky_hue, 0.4), land.a * 0.16);
    vec3 seen = mix(lit_land, depths, 0.42 + 0.3 * haze);
    col = mix(col, seen, gap * 0.85);
  }

  // A very faint light from the deep, in a few gaps only, breathing slowly.
  float patch = smoothstep(0.4, 0.8, zs_mystic_sea_noise(at * 0.9 + vec2(11.0, 4.0) + t * vec2(0.003, 0.002)));
  float breath = 0.9 + 0.1 * sin(t * 0.1 + patch * 5.0);
  vec3 glow_hue = mix(mix(vec3(1.0), sun_hue, 0.5) * vec3(1.0, 0.9, 0.96), vec3(0.75, 1.0, 1.0), day);
  glow_hue = mix(glow_hue, vec3(0.2, 0.85, 0.9), night);
  float glow_lum = mix(lum * mix(0.2, 0.22, day), 0.35, night);
  float deep = smoothstep(0.55, 0.12, h);
  col += glow_hue * glow_lum * deep * 0.6 * patch * breath * mix(0.4, 1.0, near) * (1.0 - 0.7 * overcast);
  // Under the stars the sea is lit by the moon and that glow alone; lifted
  // so it reads as a dark sea of cloud, not a void.
  col *= mix(1.0, 2.4, night);

  // Soft light falling past the plate into the gaps: sunlit air in front
  // of the sea.
  float sunup = smoothstep(-0.02, 0.15, zs_sun_direction.y) * zs_celestial_clear;
  if (sunup > 0.0) {
    float beam = zs_mystic_sea_shafts(dir);
    col += lum * mix(vec3(1.0), sun_hue, 0.5) * beam * sunup * mix(0.15, 0.09, day) * (0.6 + 0.4 * (1.0 - cover));
  }
  // Kept under the bloom: the brightest of it eases off short of white, so
  // the sea never glows round the plate's edges and pulls the eye.
  float peak = max(col.r, max(col.g, col.b));
  if (peak > 0.72) col *= (0.72 + (peak - 0.72) * 0.35) / peak;
  return vec4(col * veil, veil);
}
#endif
