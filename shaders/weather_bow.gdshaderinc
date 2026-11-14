// The rainbow on far things (scripts/endless/weather_sky_lights.gd): the bow
// is light from the drops between the eye and whatever lies behind them, so
// far land and far cloud carry it as the sky does, not only the dome's own
// pixels. A thing at `dist` m along `dir` takes the bow by how much rain-filled
// air lies before it (none nearer than ZS_BOW_NEAR.x, all past .y). Returned in
// scene-linear light: the bow as the dome adds it (zsRainbow, display colour)
// over `base` (the display colour of the sky behind, its haze), less that base.
// Needs reference_sky_common and reference_display included first.
const vec2 ZS_BOW_NEAR = vec2(700.0, 3200.0);

vec3 zs_bow_far(vec3 dir, float dist, vec3 base) {
  float a = degrees(acos(clamp(-dot(dir, zs_sun_direction), -1.0, 1.0))) / zs_bow_shape.x;
  float pw = fwidth(a);
  if (zs_bow <= 0.001 || a > 58.0) return vec3(0.0);
  float ba = zs_bow * smoothstep(ZS_BOW_NEAR.x, ZS_BOW_NEAR.y, dist);
  if (ba <= 0.001) return vec3(0.0);
  vec3 under = min(base, vec3(0.9));
  vec3 lit = min(under + zsRainbow(a, pw, dir) * ba, vec3(0.98));
  return scene_linear_for_display(lit) - scene_linear_for_display(under);
}
