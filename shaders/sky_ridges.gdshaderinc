#ifndef ZS_SKY_RIDGES
#define ZS_SKY_RIDGES
// The look pass's horizon ridges (scripts/look_pass.gd), shared by the sky
// dome that paints them and the sky objects they hide
// (shaders/sky_objects.gdshaderinc).
float zs_ridge_hash(vec3 p) {
  return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}
float zs_ridge_noise(vec3 p) {
  vec3 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(mix(zs_ridge_hash(i), zs_ridge_hash(i + vec3(1, 0, 0)), f.x),
        mix(zs_ridge_hash(i + vec3(0, 1, 0)), zs_ridge_hash(i + vec3(1, 1, 0)), f.x), f.y),
    mix(mix(zs_ridge_hash(i + vec3(0, 0, 1)), zs_ridge_hash(i + vec3(1, 0, 1)), f.x),
        mix(zs_ridge_hash(i + vec3(0, 1, 1)), zs_ridge_hash(i + vec3(1, 1, 1)), f.x), f.y),
    f.z);
}
// Ridged value noise round the circle of azimuths, so the line wraps
// with no seam. Nearer layers are busier and lower.
float zs_ridge_line(vec2 around, float layer, float seed) {
  float freq = 2.2 + layer * 1.6;
  float amp = 0.5;
  float h = 0.0;
  for (int o = 0; o < 3; o++) {
    vec3 p = vec3(around * freq, 0.0) + vec3(seed * 0.137 + layer * 17.3, layer * 5.1, seed * 0.071 + float(o) * 3.7);
    h += (1.0 - abs(zs_ridge_noise(p) * 2.0 - 1.0)) * amp;
    freq *= 2.1;
    amp *= 0.45;
  }
  return h;
}
// The height (dir.y) of ridge layer 0..2's crest at the room azimuth `around`.
float zs_ridge_top(vec2 around, float layer, float seed, float relief) {
  return mix(0.012, -0.015, layer * 0.5) + zs_ridge_line(around, layer, seed) * mix(0.07, 0.04, layer * 0.5) * relief;
}
#endif
