#ifndef ZS_SKY_SEA_DOMES
#define ZS_SKY_SEA_DOMES
// The Storybook sea's hashes, gradient noise and field of domes, apart so
// the near sea's envelope bake (shaders/sky_sea_envelope.gdshader) can draw
// them without the sea's sky; the Storybook sea (shaders/
// sky_cloud_sea_storybook.gdshaderinc) and the near sea read the same ones.
vec2 zs_storybook_sea_hash2(vec2 p) {
  p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
  return fract(sin(p) * 43758.5453) * 2.0 - 1.0;
}
// Gradient noise, -1..1-ish.
float zs_storybook_sea_gnoise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = dot(zs_storybook_sea_hash2(i), f);
  float b = dot(zs_storybook_sea_hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
  float c = dot(zs_storybook_sea_hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
  float d = dot(zs_storybook_sea_hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 1.6;
}
float zs_storybook_sea_hash1(vec2 p) {
  return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}
// One field of domes: a round puff in each cell of a jittered lattice, of
// its own size, the tallest showing; the creases fall where two meet.
float zs_storybook_sea_domes(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  float best = 0.0;
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 g = vec2(float(x), float(y));
      vec2 o = zs_storybook_sea_hash2(i + g) * 0.32 + 0.5;
      float r = 0.62 + 0.42 * zs_storybook_sea_hash1(i + g);
      vec2 d = g + o - f;
      float v = 1.0 - dot(d, d) / (r * r);
      // A smooth max: neighbouring puffs fill the crease between them.
      float k = clamp(0.5 + 0.5 * (v - best) / 0.12, 0.0, 1.0);
      best = mix(best, v, k) + 0.12 * k * (1.0 - k);
    }
  }
  return pow(max(best, 0.0), 0.7);
}
// The near sea's domes (shaders/sky_sea.gdshader, its envelope bake) are
// this many cells wide, so its heaps stand as a few broad masses for the
// cauliflower to billow on, not a field of even lumps.
const float ZS_SEA_DOME = 1.7;
#endif
