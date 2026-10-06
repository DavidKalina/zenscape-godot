#ifndef ZS_SKY_CLOUD_SEA_OPAL
#define ZS_SKY_CLOUD_SEA_OPAL
// The Opal cloud sea, as drawn on look/clouds-opal (2adc6d6): one of the
// player's three cloud styles (shaders/sky_cloud_sea.gdshaderinc picks it by
// `cloud_sea_style`; scripts/look_pass.gd sets that). Kept as its branch drew
// it; only its names carry the style, so the three can live in one shader.
// Included by shaders/sky_cloud_sea.gdshaderinc under ZS_CLOUD_SEA_SHADE,
// after the shared veil (zs_sea_veil).
// A hash without sin(): the sine of large arguments loses precision on some
// GPUs, and the sea's puffs then ran into straight-edged blocks.
float zs_opal_sea_hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}
float zs_opal_sea_noise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(zs_opal_sea_hash(i), zs_opal_sea_hash(i + vec2(1.0, 0.0)), f.x),
             mix(zs_opal_sea_hash(i + vec2(0.0, 1.0)), zs_opal_sea_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
// Where the sea parts (a threshold on slow noise): rarer as x rises.
const vec2 SEA_RIFTS = vec2(0.68, 0.88);
// How soft the creases between neighbouring puffs are.
const float SEA_CREASE = 0.22;
// Heaped puffs: a dome on a jittered lattice of cells, the tallest at each
// point, so neighbours meet in creases like the tops of a cumulus field.
float zs_opal_sea_puffs(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  float top = 0.0;
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 g = vec2(float(x), float(y));
      vec2 c = i + g;
      vec2 d = g + vec2(zs_opal_sea_hash(c), zs_opal_sea_hash(c + vec2(17.3, 5.1))) - f;
      float r = 0.6 + 0.4 * zs_opal_sea_hash(c + vec2(3.7, 11.9));
      // A smooth maximum, so neighbours meet in soft valleys, not cracks.
      float dome = sqrt(max(1.0 - dot(d, d) / (r * r), 0.0)) * r;
      float k = clamp(0.5 + 0.5 * (dome - top) / SEA_CREASE, 0.0, 1.0);
      top = mix(top, dome, k) + SEA_CREASE * k * (1.0 - k);
    }
  }
  return top;
}
// Now and then the sea parts: a few rifts, where the land shows. 0 closed.
float zs_opal_sea_rift(vec2 q) {
  vec2 r1 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * q;
  vec2 r2 = mat2(vec2(0.28, -0.96), vec2(0.96, 0.28)) * q;
  float rn = zs_opal_sea_noise(r1 * 0.9 + vec2(11.3, 4.1)) * 0.7 + zs_opal_sea_noise(r2 * 2.1 + vec2(2.6, 9.2)) * 0.3;
  return smoothstep(SEA_RIFTS.x, SEA_RIFTS.y, rn);
}
// The sea's height: broad masses of heaped puffs, finer puffs on them. Each
// layer fades to its mean where it would shimmer (`blur` is the pattern's
// footprint per pixel), so the far sea goes smooth instead of crawling.
float zs_opal_sea_billows(vec2 q, float blur) {
  // Turned off the lattice, so no straight noise seams run into the distance.
  vec2 r1 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * q;
  vec2 r2 = mat2(vec2(0.28, -0.96), vec2(0.96, 0.28)) * q;
  float mass = zs_opal_sea_noise(r1 * 0.3 + vec2(5.2, 1.7)) * 0.5 + zs_opal_sea_noise(r2 * 0.57 + vec2(1.3, 8.1)) * 0.3
    + zs_opal_sea_noise(q * 1.13 + vec2(4.4, 2.2)) * 0.2;
  float h = 0.0;
  float amp = 0.62;
  float freq = 1.0;
  for (int o = 0; o < 3; o++) {
    float keep = 1.0 - smoothstep(0.22, 0.6, blur * freq);
    h += mix(0.55, zs_opal_sea_puffs(q * freq + vec2(float(o) * 7.3, float(o) * 3.1)), keep) * amp;
    freq *= 2.3;
    amp *= 0.42;
  }
  return h * mix(0.7, 1.15, smoothstep(0.15, 0.85, mass)) * (1.0 - 0.3 * zs_opal_sea_rift(q));
}

// The opal look's dials, display-space.
const float SEA_WARP = 0.45;
// Puffs a second the sea drifts, and how fast its warp turns over.
const float SEA_DRIFT = 0.016;
const float SEA_CHURN = 0.012;
// Puffs per depth below the eye.
const float SEA_SCALE = 1.25;
const vec2 SEA_COVER = vec2(0.24, 0.42);
// Pearl tops, cool shadows and troughs, as shares of the horizon's brightness.
const vec3 SEA_LEVELS = vec3(1.22, 0.74, 0.6);
const float SEA_TOP_GAIN = 1.0;
const vec2 SEA_CROWN = vec2(0.4, 0.82);
// The moonlit sea at night: its floor of display brightness.
const float SEA_NIGHT_LEVEL = 0.17;
const float SEA_SUN_TINT = 0.35;
const vec3 SEA_SHADOW = vec3(0.84, 0.88, 0.98);
const vec3 SEA_GOLDEN_SHADOW = vec3(1.0, 0.84, 0.88);
// Inner glow on the rims: everywhere, and more toward the sun.
const vec2 SEA_GLOW = vec2(0.03, 0.1);
const float SEA_OPAL = 0.2;
const float SEA_SHEEN = 0.12;
const float SEA_HAZE = 0.16;
const float SEA_OVERCAST_LIFT = 0.3;
// The land under the sea: x its scale per depth below the eye (larger is
// deeper), y how much air veils it.
const vec2 SEA_LAND = vec2(6.0, 0.42);
// How far under the sea that land lies, in depths of the sea below the eye.
const float SEA_LAND_DEPTH = 6.0;
// The ocean among that land: x its scale per depth (small is broad), y the
// mask's threshold (higher is less sea).
const vec2 SEA_OCEAN = vec2(0.3, 0.5);

// Mother-of-pearl: a slow round of pastel tints at about unit brightness,
// lilac to mint to peach and back, for the sea's opal sheen.
vec3 zs_opal_sea_opal(float t) {
  vec3 lilac = vec3(0.92, 0.86, 1.10);
  vec3 mint = vec3(0.86, 1.06, 1.00);
  vec3 peach = vec3(1.10, 0.95, 0.86);
  float k = fract(t) * 3.0;
  float f = smoothstep(0.0, 1.0, fract(k));
  if (k < 1.0) return mix(lilac, mint, f);
  if (k < 2.0) return mix(mint, peach, f);
  return mix(peach, lilac, f);
}

// The ground under the sea, seen through its rifts from `at` (the point on
// the sea): far deeper, so its fields are small beside the puffs. Lit by
// the hour (`level`), before any air: the near sea (shaders/sky_sea
// .gdshader) lays its own, by the metre.
vec3 zs_opal_sea_land_lit(vec2 at, float blur, float level, vec3 pearl, float glint) {
  vec2 g = at * SEA_LAND.x + vec2(41.0, 17.0);
  float fine = 1.0 - smoothstep(0.25, 0.8, blur * SEA_LAND.x * 3.0 / SEA_SCALE);
  float fields = zs_opal_sea_noise(g * 1.6);
  float spot = zs_opal_sea_noise(g * 3.1 + vec2(5.0, 2.0));
  float woods = smoothstep(0.5, 0.62, zs_opal_sea_noise(g * 0.9 + vec2(9.0, 3.0)) * 0.7 + zs_opal_sea_noise(g * 2.9) * 0.3);
  vec3 land = mix(vec3(0.36, 0.5, 0.3), vec3(0.62, 0.6, 0.4), smoothstep(0.35, 0.65, fields));
  land = mix(land, land * vec3(0.9, 1.0, 0.92), (spot - 0.5) * fine);
  land = mix(land, vec3(0.26, 0.36, 0.30), woods * 0.8);
  // A river: one slow meandering line, catching the light.
  vec2 m = mat2(vec2(0.6, -0.8), vec2(0.8, 0.6)) * g;
  float wind = zs_opal_sea_noise(m * 0.35) + 0.5 * zs_opal_sea_noise(m * 0.9 + vec2(3.0, 1.0));
  float width = max(0.004, fwidth(wind) * 0.8);
  float river = (1.0 - smoothstep(width, width * 2.0, abs(wind - 0.75))) * fine;
  // Seen only in reaches, where it catches the light.
  river *= smoothstep(0.45, 0.75, zs_opal_sea_noise(g * 0.6 + vec2(7.0, 1.0)));
  land = mix(land, pearl * 1.05, river * 0.28);
  // Over broad regions of the world the ground is sea: a wide mask, a soft
  // coast with a pale shore, deep blue farther out.
  float coast = zs_opal_sea_noise(at * SEA_OCEAN.x + vec2(13.0, 7.0)) * 0.75 + zs_opal_sea_noise(g * 0.35) * 0.25;
  float ocean = smoothstep(SEA_OCEAN.y - 0.035, SEA_OCEAN.y + 0.035, coast);
  land = mix(land, vec3(0.74, 0.7, 0.56), smoothstep(SEA_OCEAN.y - 0.1, SEA_OCEAN.y - 0.02, coast) * (1.0 - ocean) * 0.6);
  vec3 water = mix(vec3(0.22, 0.5, 0.58), vec3(0.1, 0.24, 0.46), smoothstep(SEA_OCEAN.y, SEA_OCEAN.y + 0.2, coast));
  // Long soft swell, and a glint where the water catches the light.
  float swell = zs_opal_sea_noise(g * vec2(2.2, 6.0) + vec2(3.0, 8.0)) * 0.6 + zs_opal_sea_noise(g * vec2(5.5, 14.0)) * 0.4;
  float sparkle = smoothstep(0.55, 0.85, swell) * fine;
  water *= 0.94 + 0.12 * swell * fine;
  water += pearl * glint * (0.05 + 0.22 * sparkle);
  land = mix(land, water / max(level * 1.05, 1e-3), ocean);
  // Lit by the hour.
  return land * level * 1.05;
}

// The same, as the dome sees it: deep in the air between, blue-grey and
// faint. Display colour, already in the air's haze.
vec3 zs_opal_sea_land(vec2 at, float blur, float level, vec3 shadow_hue, vec3 pearl, float dusk, float glint) {
  vec3 land = zs_opal_sea_land_lit(at, blur, level, pearl, glint);
  vec3 air = shadow_hue * level * 0.88;
  // Low light leaves the land to the air: a hint, never a dark hole.
  return mix(land, air, min(SEA_LAND.y + 0.25 * dusk, 0.85));
}


// Distant peaks rising through the sea. Each is a cone of faceted rock with
// its foot in the cloud: xy its place on the sea (depths from the eye, in the
// room's frame), z its radius, w its height above the sea. The eye is one
// depth above the sea, so a peak stays below the horizon.
const int SEA_PEAKS = 5;
// How much of them is painted (0 to 1): none where real ranges stand round
// the sky world (scripts/sky_world.gd: the look pass sets it, LookPass
// `apply_sea_peaks`), since these travel with the eye and beside the real
// rock read wrong.
uniform float sea_peaks = 1.0;
vec4 zs_opal_sea_peak(int i) {
  if (i == 0) return vec4(vec2(cos(0.5), sin(0.5)) * 1.7, 0.26, 0.5);
  if (i == 1) return vec4(vec2(cos(2.5), sin(2.5)) * 2.0, 0.23, 0.44);
  if (i == 2) return vec4(vec2(cos(2.78), sin(2.78)) * 2.3, 0.19, 0.37);
  if (i == 3) return vec4(vec2(cos(4.7), sin(4.7)) * 1.8, 0.27, 0.52);
  return vec4(vec2(cos(5.9), sin(5.9)) * 2.1, 0.21, 0.42);
}
// Value noise, linear between lattice points: flat planes, so rock facets.
float zs_opal_sea_flat(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  return mix(mix(zs_opal_sea_hash(i), zs_opal_sea_hash(i + vec2(1.0, 0.0)), f.x),
             mix(zs_opal_sea_hash(i + vec2(0.0, 1.0)), zs_opal_sea_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float zs_opal_sea_peak_height(vec2 d, vec4 pk, float seed) {
  float r = length(d) / pk.z;
  if (r >= 1.0) return 0.0;
  vec2 e = d / pk.z * 4.0 + vec2(seed, seed * 1.7);
  float facet = zs_opal_sea_flat(e) * 0.6 + zs_opal_sea_flat(e * 2.1 + 4.0) * 0.4;
  return pk.w * pow(1.0 - r, 1.15) * (0.62 + 0.76 * facet);
}
// The peaks along a ray: x coverage, rgb colour (already hazed, not premultiplied).
vec4 zs_opal_sea_peaks(vec2 u, float far, vec3 lamp, float level, vec3 pearl, vec3 shadow_hue, vec3 air, float overcast) {
  for (int i = 0; i < SEA_PEAKS; i++) {
    vec4 pk = zs_opal_sea_peak(i);
    float seed = float(i) * 5.3 + 1.0;
    float s0 = dot(pk.xy, u);
    vec2 perp = pk.xy - u * s0;
    float d2 = dot(perp, perp);
    if (s0 <= 0.0 || d2 >= pk.z * pk.z) continue;
    float chord = sqrt(pk.z * pk.z - d2);
    float sa = max(s0 - chord, 0.0), sb = min(s0 + chord, far);
    if (sa >= sb) continue;
    float prev_f = -1.0, prev_s = sa;
    float hit_s = -1.0;
    for (int k = 1; k <= 16; k++) {
      float s = mix(sa, sb, float(k) / 16.0);
      float f = zs_opal_sea_peak_height(u * s - pk.xy, pk, seed) - (1.0 - s / far);
      if (f >= 0.0) {
        hit_s = mix(prev_s, s, clamp(-prev_f / (f - prev_f + 1e-5), 0.0, 1.0));
        break;
      }
      prev_f = f; prev_s = s;
    }
    if (hit_s < 0.0) continue;
    vec2 pos = u * hit_s - pk.xy;
    float hh = 1.0 - hit_s / far;
    const float PEAK_EPS = 0.03;
    float dx = zs_opal_sea_peak_height(pos + vec2(PEAK_EPS, 0.0), pk, seed) - zs_opal_sea_peak_height(pos - vec2(PEAK_EPS, 0.0), pk, seed);
    float dz = zs_opal_sea_peak_height(pos + vec2(0.0, PEAK_EPS), pk, seed) - zs_opal_sea_peak_height(pos - vec2(0.0, PEAK_EPS), pk, seed);
    vec3 n = normalize(vec3(-dx, 2.0 * PEAK_EPS, -dz));
    float lam = clamp(dot(n, lamp) * 0.95 + 0.12, 0.0, 1.0);
    // Snow on the high ground of the tall peaks, bare rock on the rest.
    float line = (i == 0 || i == 3) ? 0.3 : 0.7;
    float snow = smoothstep(line, line + 0.15, hh / pk.w + (zs_opal_sea_flat(pos * 9.0) - 0.5) * 0.18);
    vec3 rock = vec3(0.4, 0.43, 0.52) * mix(1.0, 0.8, zs_opal_sea_flat(pos * 5.0 + seed));
    vec3 albedo = mix(rock, vec3(0.97, 0.98, 1.0), snow);
    vec3 lit = mix(shadow_hue * level * 0.7, pearl * min(level * 1.25, 0.97), lam);
    vec3 c = albedo * lit;
    // Far air: the shade side most of all.
    float haze = clamp(1.0 - exp(-hit_s * 0.12) + 0.14 + 0.2 * (1.0 - lam), 0.0, 0.7);
    c = mix(c, mix(air, shadow_hue * level, 0.4), haze);
    // The foot is lost in the cloud.
    float foot = smoothstep(0.03, 0.2 + 0.1 * zs_opal_sea_flat(pos * 6.0), hh);
    return vec4(c, foot * (1.0 - 0.3 * overcast));
  }
  return vec4(0.0);
}

// The sea along `dir` (world) / `room` (the room's turn of it), premultiplied:
// rgb already times alpha. `horizon` is the sky's colour along the flattened
// direction, the air it dissolves into; `below` the dome's own colour along
// `dir`. The look is luminous opal: pearl tops lit from within, cool clean
// shadows, a whisper of mother-of-pearl over the billows' rims, a soft
// sheen on the side toward the sun, and a few rifts onto the land below. Its brightness follows the horizon's, so
// it keeps the hour's (and the look's) light; its hues follow the sun's and
// the sky's colours, so golden hour stays peach and night stays silver.
vec4 zs_cloud_sea_opal(vec3 dir, vec3 room, vec3 horizon, vec3 below) {
  float veil = zs_sea_veil(dir);
  // The peaks stand clear of the night's pulled-down veil: dim silver, not gone.
  float peak_veil = (cloud_sea > 0.0 && dir.y < -0.02) ? cloud_sea * smoothstep(-0.02, -0.16, dir.y) : 0.0;
  if (peak_veil <= 0.0) return vec4(0.0);
  float down = max(-dir.y, 0.02);
  // Where the ray meets the sea, in depths below the eye. `far` stays the
  // view's own (haze and peaks); `at`, the place on the sea, follows the
  // glide (zs_sea_flight): nearer as it falls, sliding by as it flies.
  vec2 seen = room.xz / down;
  float far = length(seen);
  vec2 at = seen * zs_sea_flight.z + zs_sea_flight.xy;
  // Broad billows, drifting on the wind; a slow warp heaps them into
  // rounded mounds, and the warp itself turns over in time, so the puffs
  // swell and settle as they go.
  vec2 q = at * SEA_SCALE + vec2(0.6, 0.35) * zs_motion_time * SEA_DRIFT;
  float blur = length(fwidth(q));
  float warp_keep = 1.0 - smoothstep(0.35, 1.1, blur);
  vec2 churn = vec2(1.0, -0.6) * zs_motion_time * SEA_CHURN;
  q += (vec2(zs_opal_sea_noise(q * 0.45 + vec2(3.1, 7.7) + churn), zs_opal_sea_noise(q * 0.45 + vec2(9.4, 1.3) - churn)) - 0.5) * SEA_WARP * warp_keep;
  float h = zs_opal_sea_billows(q, blur);
  // The side of each billow that faces the sun, by a step toward it.
  vec3 sun_room = zsRoomDir(zs_sun_direction);
  vec2 toward = normalize(sun_room.xz + 1e-4);
  float ahead = zs_opal_sea_billows(q + toward * 0.08, blur);
  float lit = clamp((h - ahead) * 6.0 + 0.5, 0.0, 1.0);
  // Calm overcast: flatter light, less relief, less play of colour.
  float overcast = smoothstep(0.35, 0.9, zs_cloud.x);
  float relief = mix(1.0, 0.5, overcast);
  // One sea of rounded crowns, cool troughs between them.
  float cover = smoothstep(SEA_COVER.x, SEA_COVER.y, h);
  float crown = smoothstep(SEA_CROWN.x, SEA_CROWN.y, h);
  // The billows' thin rims, where light comes through.
  float rim = cover * (1.0 - cover) * 4.0;

  // Brightness from the sky's horizon, so the sea keeps the hour's light.
  const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
  float level = dot(horizon, LUMA);
  level = max(level, SEA_NIGHT_LEVEL * zs_night * zs_celestial_clear);
  // Under overcast the sea stays a silvery pearl, a step brighter than the grey dome.
  level *= 1.0 + SEA_OVERCAST_LIFT * overcast * (1.0 - zs_night);
  vec3 sun_hue = zs_cloud_sun / max(max(max(zs_cloud_sun.r, zs_cloud_sun.g), zs_cloud_sun.b), 1e-3);
  vec3 sky_hue = zs_cloud_sky / max(max(max(zs_cloud_sky.r, zs_cloud_sky.g), zs_cloud_sky.b), 1e-3);
  // A low sun warms the whole sea: peach tops, rose-lilac shadows.
  float golden = smoothstep(0.35, 0.06, zs_sun_direction.y) * smoothstep(-0.12, 0.0, zs_sun_direction.y) * (1.0 - overcast);
  vec3 pearl = mix(vec3(0.97, 0.97, 1.0), sun_hue, mix(SEA_SUN_TINT, 0.5, golden));
  vec3 shadow_hue = mix(mix(SEA_SHADOW, sky_hue, 0.35), SEA_GOLDEN_SHADOW, golden * 0.6);
  vec3 top = pearl * min(level * SEA_LEVELS.x, 0.95);
  vec3 shade = shadow_hue * level * SEA_LEVELS.y;
  vec3 trough = shadow_hue * vec3(0.92, 0.95, 1.0) * level * SEA_LEVELS.z;
  // Toward the sun the sea glows: forward light through thin cloud.
  float az = dot(normalize(room.xz + 1e-5), toward);
  float ahead_of_sun = pow(0.5 + 0.5 * az, 3.0) * smoothstep(-0.03, 0.12, zs_sun_direction.y + 0.1);
  float light = crown * mix(1.0, mix(0.45, 1.05, lit), relief);
  vec3 col = mix(trough, shade, cover);
  col = mix(col, top, clamp(light * SEA_TOP_GAIN, 0.0, 1.0));
  // Lit from within: rims glow in the sun's colour, most toward the sun.
  col += pearl * level * rim * (SEA_GLOW.x + SEA_GLOW.y * ahead_of_sun) * relief;
  // Mother-of-pearl, shifting with the view, the billows' height and slowly in time.
  float play = h * 1.7 + az * 0.3 + dir.y * 1.1 + far * 0.05 + zs_motion_time * 0.002;
  float opal = SEA_OPAL * (0.35 + 0.65 * rim + 0.4 * crown) * mix(1.0, 0.35, overcast);
  col *= mix(vec3(1.0), zs_opal_sea_opal(play), opal);
  // A broad sheen on the sea toward the sun, a soft bloom where it catches.
  col += pearl * level * SEA_SHEEN * ahead_of_sun * (0.4 + 0.6 * cover) * smoothstep(-0.75, -0.08, dir.y) * relief;
  // The land far below, glimpsed through the rifts: fields, woods and a
  // river glint, deep in the air's blue so it never competes with the plate.
  // The rift's edge follows the puffs: crowns hold out, valleys open first,
  // and the thinning cloud at the edge brightens rather than darkens.
  float rift = zs_opal_sea_rift(q);
  float open = rift * 1.3 - (h - 0.45) * 2.0;
  // Under a falling glide the sea parts: a ring opening round the point
  // straight below, crowns holding out longest, the edge frayed.
  float part = zs_sea_flight.w;
  float hole = 0.0;
  if (part > 0.0) {
    float fray = zs_opal_sea_noise(q * 3.1 + vec2(8.2, 2.9)) - 0.5;
    hole = (1.0 - smoothstep(part * 0.9, part * 0.9 + 0.45, length(seen) + fray * 0.5 + (h - 0.45) * 0.6)) * smoothstep(0.0, 0.25, part);
  }
  if (open > 0.1 || hole > 0.0) {
    // Ragged, wispy edges: fine cloud fraying over the land.
    float wisp = zs_opal_sea_noise(q * 4.3 + vec2(1.7, 6.1)) * 0.6 + zs_opal_sea_noise(q * 9.1 + vec2(4.2, 0.3)) * 0.4;
    open = open > 0.1 ? smoothstep(0.3, 0.85, open + (wisp - 0.5) * 0.45 * warp_keep) : 0.0;
    open = max(open, hole);
    col += pearl * level * 0.04 * open * (1.0 - open) * 4.0;
    // The light on the water: the sun by day, the moon by night.
    vec3 lamp = normalize(mix(sun_room, zsRoomDir(zs_moon_direction), zs_night * zs_celestial_clear));
    float lamp_az = dot(normalize(room.xz + 1e-5), normalize(lamp.xz + 1e-4));
    float glint = pow(0.5 + 0.5 * lamp_az, 8.0) * smoothstep(-0.05, 0.2, lamp.y) * mix(1.0, 0.5, zs_night) * (1.0 - overcast);
    // The land lies SEA_LAND_DEPTH depths under the sea, so a glide's fall
    // and flight move it far less than the cloud.
    vec2 land_at = (seen * (zs_sea_flight.z + SEA_LAND_DEPTH) + zs_sea_flight.xy) / (1.0 + SEA_LAND_DEPTH);
    col = mix(col, zs_opal_sea_land(land_at, blur, level, shadow_hue, pearl, max(golden, zs_night), glint), open);
  } else open = 0.0;
  // Clear air: the far sea lifts into a luminous haze, not into murk.
  float haze = 1.0 - exp(-far * SEA_HAZE);
  vec3 air = mix(horizon, pearl * level, 0.45);
  col = mix(col, air, haze);
  // Distant peaks through the sea, in front of the cloud they rise from.
  vec3 lamp_pk = normalize(mix(sun_room, zsRoomDir(zs_moon_direction), zs_night * zs_celestial_clear));
  vec4 peak = sea_peaks > 0.0 ? zs_opal_sea_peaks(normalize(room.xz + 1e-5), far, lamp_pk, level * (1.0 + 1.4 * zs_night * zs_celestial_clear), pearl, shadow_hue, air, overcast) : vec4(0.0);
  float peak_a = peak.a * peak_veil * clamp(sea_peaks, 0.0, 1.0);
  // At night the sea under the moon still reads, faintly silver.
  col += zs_cloud_sun * crown * lit * relief * (1.0 - haze) * 0.06 * zs_night * zs_celestial_clear;
  return vec4(col * veil * (1.0 - peak_a) + peak.rgb * peak_a, mix(veil, 1.0, peak_a));
}
#endif
