#ifndef ZS_CLOUD_FIELD
#define ZS_CLOUD_FIELD
#include "res://shaders/reference_globals.gdshaderinc"
// Original weather.js cloud/noise/phase field.

float wxHash(vec3 p) {
  p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
  p *= 17.0;
  return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float wxNoise(vec3 x) {
  vec3 i = floor(x);
  vec3 f = fract(x);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(mix(wxHash(i + vec3(0.0, 0.0, 0.0)), wxHash(i + vec3(1.0, 0.0, 0.0)), f.x),
        mix(wxHash(i + vec3(0.0, 1.0, 0.0)), wxHash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
    mix(mix(wxHash(i + vec3(0.0, 0.0, 1.0)), wxHash(i + vec3(1.0, 0.0, 1.0)), f.x),
        mix(wxHash(i + vec3(0.0, 1.0, 1.0)), wxHash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}
float wxFbm(vec3 p) {
  float amp = 0.5, sum = 0.0;
  for (int i = 0; i < 4; i++) { sum += amp * wxNoise(p); p *= 2.07; amp *= 0.5; }
  return sum;
}
// Two octaves, for the paths that run MANY times per pixel: the light march
// inside the cloud, and the shadow lookup every lit surface does. Detail there
// is invisible anyway — it's being integrated or blurred by the sun's own
// softness — and it's the difference between 60fps and a slideshow.
// Interleaved gradient noise — the standard ray-start offset. A hash gives
// static (every neighbour disagrees at random); a 4x4 Bayer grid gives a
// crosshatch you can see from across the room, because the pattern repeats
// every four pixels. IGN is neither: locally well-spread, with no period short
// enough to read as texture.
float wxDither(vec2 px) {
  return fract(52.9829189 * fract(dot(px, vec2(0.06711056, 0.00583715))));
}
float wxFbm2(vec3 p) {
  return 0.5 * wxNoise(p) + 0.25 * wxNoise(p * 2.07);
}







   // the tallest peak: (x, height, z)
  // the way the wind blows, in xz
     // how hard the sky answers the relief (update)
    // the condensation level, world y (update)

// THE DECK NOTICES THE MOUNTAIN (ADR 0018). Air forced over a peak keeps
// rising and falling downwind of it — a standing wave, fixed to the ground
// while the air streams through it — and cloud condenses on every crest of
// the wave. So the field is lifted over the summit and again in bands
// downwind, each fainter than the last, and the drift carries texture
// THROUGH the bands without moving them. s is distance along the wind,
// c across it; the train is a ridge of cos() fourteen units apart.
float orogDeck(vec3 p) {
  vec2 r = p.xz - zs_summit.xyz.xz;
  float s = dot(r, zs_wind_direction);
  float c = dot(r, vec2(-zs_wind_direction.y, zs_wind_direction.x));
  float train = smoothstep(-7.0, 0.0, s) * exp(-max(s, 0.0) * 0.033) * exp(-c * c * 0.0062);
  float wave = 0.5 + 0.5 * cos(0.449 * max(s, 0.0));
  return zs_summit.w * train * wave;
}

// The cheap twin of cloudAt: same threshold, same drift, two octaves. Used
// wherever the answer is about to be averaged away.
float cloudRough(vec3 p) {
  float h = clamp((p.y - zs_cloud.z) / zs_cloud.w, 0.0, 1.0);
  float prof = smoothstep(0.0, 0.10, h) * smoothstep(1.0, 0.45, h);
  float d = wxFbm2(p * 0.019 + zs_cloud_drift) - mix(0.60, 0.19, zs_cloud.x) + 0.20 * orogDeck(p);
  return max(d, 0.0) * (5.5 + 3.0 * zs_cloud.y) * prof;
}

float cloudAt(vec3 p) {
  float h = clamp((p.y - zs_cloud.z) / zs_cloud.w, 0.0, 1.0);
  // A cumulus has a FLAT BOTTOM (the condensation level is a height, not a
  // shape) and a billowing, fraying top. That asymmetry is most of why a blob
  // of noise reads as weather rather than as smoke.
  float prof = smoothstep(0.0, 0.10, h) * smoothstep(1.0, 0.45, h);
  vec3 q = p * 0.019 + zs_cloud_drift;
  // The remaining two octaves add at most .1875. Empty parcels can skip
  // those octaves and edge erosion without changing the visible field.
  float lift = 0.20 * orogDeck(p);
  float threshold = mix(0.74, 0.24, zs_cloud.x);
  float base = wxFbm2(q);
  if (base + 0.1875 + lift <= threshold) return 0.0;
  vec3 fine = q * 2.07 * 2.07;
  base += 0.125 * wxNoise(fine);
  base += 0.0625 * wxNoise(fine * 2.07);
  // Coverage is a THRESHOLD on the field, not an opacity. That matters: at
  // low coverage you get separated puffs with sky between them (and therefore
  // shafts); fading a full sky out would just give you thin overcast.
  float d = base - threshold + lift;
  // erode the edges with a faster octave so they fray instead of cutting
  d -= (0.13 + 0.22 * zs_cloud.y) * wxFbm(q * 4.3 + 7.0) * (1.0 - h * 0.4);
  return max(d, 0.0) * (5.5 + 3.0 * zs_cloud.y) * prof;
}

// How shaded is a world point by the clouds above it? Walk up the sun vector
// to the cloud deck and ask the same field. Because it IS the same field, the
// dark patches on the hillside line up with the clouds you can see.
float cloudShadeAt(vec3 world, vec3 sunDir) {
  float yc = zs_cloud.z + zs_cloud.w * 0.42;
  float t = (yc - world.y) / max(sunDir.y, 0.2);
  vec3 p = world + sunDir * t;
  return exp(-cloudRough(vec3(p.x, yc, p.z)) * 0.55);
}


float hg(float ct, float g) {
  float g2 = g * g;
  return (1.0 - g2) / (12.566371 * pow(1.0 + g2 - 2.0 * g * ct, 1.5));
}

// Air belongs to the plate (scripts/plate.gd, zs_plate_half; 14 m). A fog point
// is kept only where the eye sees it against land: the sight line through it,
// carried on down to its ground, must still land inside the rim, with a soft
// band from 5 m to 1.5 m in. Seen level or from below, the void is behind it.
// Mist over the far rim, which a raised view saw past the rim against the void,
// thins out; the same mist is kept wherever the land is behind it.
float zs_plate_keep(vec3 p, float ground) {
  float lift = max(p.y - ground, 0.0);
  float drop = zs_camera_position.y - p.y;
  if (lift > 0.0 && drop <= 0.001) return 0.0;
  vec2 land = p.xz + (p.xz - zs_camera_position.xz) * (lift / max(drop, 0.001));
  float clear = zs_plate_half - max(max(abs(p.x), abs(p.z)), max(abs(land.x), abs(land.y)));
  return smoothstep(1.5, 5.0, clear);
}

#endif
