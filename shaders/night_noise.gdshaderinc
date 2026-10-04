#ifndef ZS_NIGHT_NOISE
#define ZS_NIGHT_NOISE
// Noise for the night sky's styles (shaders/night_sky.gdshaderinc). The old
// Milky Way ran on a sin() hash, whose precision fails at large arguments on
// some GPUs and breaks into straight-edged blocks, and on value noise that
// stacked its octaves on one lattice, so the cells' axes showed as boxes.
// Here the hash is sin-free, the noise is gradient noise (no flat cell
// plateaus) and each octave is turned off the last one's lattice.

// A sin-free hash of a lattice point, three values in 0..1.
vec3 zs_night_hash3(vec3 p) {
  p = fract(p * vec3(0.1031, 0.1030, 0.0973));
  p += dot(p, p.yxz + 33.33);
  return fract((p.xxy + p.yxx) * p.zyx);
}
float zs_night_hash(vec3 p) {
  p = fract(p * 0.1031);
  p += dot(p, p.zyx + 31.32);
  return fract((p.x + p.y) * p.z);
}

// Gradient noise in -1..1, smooth (quintic) between lattice points.
float zs_night_noise(vec3 p) {
  vec3 i = floor(p);
  vec3 f = fract(p);
  vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
  float n000 = dot(zs_night_hash3(i) * 2.0 - 1.0, f);
  float n100 = dot(zs_night_hash3(i + vec3(1, 0, 0)) * 2.0 - 1.0, f - vec3(1, 0, 0));
  float n010 = dot(zs_night_hash3(i + vec3(0, 1, 0)) * 2.0 - 1.0, f - vec3(0, 1, 0));
  float n110 = dot(zs_night_hash3(i + vec3(1, 1, 0)) * 2.0 - 1.0, f - vec3(1, 1, 0));
  float n001 = dot(zs_night_hash3(i + vec3(0, 0, 1)) * 2.0 - 1.0, f - vec3(0, 0, 1));
  float n101 = dot(zs_night_hash3(i + vec3(1, 0, 1)) * 2.0 - 1.0, f - vec3(1, 0, 1));
  float n011 = dot(zs_night_hash3(i + vec3(0, 1, 1)) * 2.0 - 1.0, f - vec3(0, 1, 1));
  float n111 = dot(zs_night_hash3(i + vec3(1, 1, 1)) * 2.0 - 1.0, f - vec3(1, 1, 1));
  return mix(mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
             mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y), u.z) * 1.6;
}

// The same in 0..1.
float zs_night_noise01(vec3 p) {
  return clamp(0.5 + 0.5 * zs_night_noise(p), 0.0, 1.0);
}

// Turns each octave off the last one's lattice, so no axis lines up.
const mat3 ZS_NIGHT_TURN = mat3(vec3(0.00, 0.80, 0.60), vec3(-0.80, 0.36, -0.48), vec3(-0.60, -0.48, 0.64));

// `octaves` of gradient noise in 0..1. Each octave fades to its mean where
// it would be finer than a pixel (`blur`, the pattern's footprint per pixel
// at p's scale: pass length(fwidth(p)), or 0 to keep them all), so the far
// detail settles rather than crawling.
float zs_night_fbm(vec3 p, int octaves, float blur) {
  float sum = 0.0;
  float amp = 0.5;
  float total = 0.0;
  float scale = 1.0;
  for (int i = 0; i < 6; i++) {
    if (i >= octaves) break;
    float keep = 1.0 - smoothstep(0.25, 0.6, blur * scale);
    sum += amp * zs_night_noise(p) * keep;
    total += amp;
    p = ZS_NIGHT_TURN * p * 2.03 + vec3(1.7, 9.2, 3.1);
    scale *= 2.03;
    amp *= 0.5;
  }
  return clamp(0.5 + 0.5 * sum / total, 0.0, 1.0);
}
#endif
