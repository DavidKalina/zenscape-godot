shader_type spatial;
// The planet's body: a low-poly sphere lit flat per facet by the real sun,
// so its terminator follows the day and it hangs as a lit crescent or a full
// disc. Soft bands of weather run round it, and its limb glows.
render_mode unshaded, blend_mix, depth_draw_never, cull_back, fog_disabled, shadows_disabled;
#include "res://shaders/sky_planet.gdshaderinc"

varying vec3 local;
varying vec3 world;
varying float clouds;

void vertex() {
  // A slow turn on its pole, so the band detail drifts.
  float spin = zs_motion_time * 0.004;
  local = mat3(vec3(cos(spin), 0.0, -sin(spin)), vec3(0.0, 1.0, 0.0), vec3(sin(spin), 0.0, cos(spin))) * VERTEX;
  vec3 centre = zs_planet_centre(CAMERA_POSITION_WORLD);
  world = centre + zs_planet_axes() * VERTEX * zs_planet_world_radius();
  clouds = zs_cloud_transmit(CAMERA_POSITION_WORLD, normalize(world - CAMERA_POSITION_WORLD));
  POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(world, 1.0));
}

void fragment() {
  vec3 view = normalize(world - CAMERA_POSITION_WORLD);
  vec3 centre = zs_planet_centre(CAMERA_POSITION_WORLD);
  // The facet's own normal: the solid stays cut, the light on it soft.
  vec3 facet = normalize(cross(dFdx(world), dFdy(world)));
  if (dot(facet, view) > 0.0) facet = -facet;
  vec3 radial = normalize(world - centre);
  float sun = dot(facet, zs_sun_direction);
  float lit = smoothstep(-0.12, 0.85, sun);
  // Bands of weather: cream, apricot and rust, wavering with latitude.
  vec3 p = normalize(local);
  float lat = p.y + 0.06 * sin(p.x * 7.0 + p.z * 5.0) + 0.04 * sin(atan(p.z, p.x) * 3.0 + p.y * 11.0);
  float band = 0.5 + 0.5 * sin(lat * 13.0 + 1.3 * sin(lat * 4.0));
  float fine = 0.5 + 0.5 * sin(lat * 41.0 + 2.0);
  vec3 base = mix(vec3(0.62, 0.38, 0.29), vec3(0.93, 0.84, 0.68), band);
  base = mix(base, vec3(0.86, 0.6, 0.42), fine * 0.35 * (1.0 - abs(p.y)));
  // A faint ashen light on the night side, so the whole disc reads.
  vec3 col = base * (0.035 + 0.9 * lit);
  // The limb's atmosphere: thin and bright where the sun reaches it.
  float limb = pow(1.0 - max(dot(radial, -view), 0.0), 3.0);
  float day = smoothstep(-0.35, 0.5, dot(radial, zs_sun_direction));
  col += vec3(0.55, 0.8, 1.0) * limb * (0.08 + 0.55 * day);
  vec3 room = zs_room_from_world(view);
  float presence = zs_planet_presence(view, room) * clouds;
  ALBEDO = scene_linear_for_display(clamp(col, 0.0, 1.0));
  ALPHA = presence * mix(max(lit, limb * day) * 0.35, 1.0, zs_night);
}
