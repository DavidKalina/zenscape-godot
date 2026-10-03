shader_type spatial;
// The planet's rings: a flat band of fine dust lanes round its equator, lit
// by the sun, with the planet's shadow across them and the body hiding the
// far side.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
#include "res://shaders/sky_planet.gdshaderinc"

varying vec3 local;
varying vec3 world;
varying float clouds;

void vertex() {
  local = VERTEX;
  world = zs_planet_centre(CAMERA_POSITION_WORLD) + zs_planet_axes() * VERTEX * zs_planet_world_radius();
  clouds = zs_cloud_transmit(CAMERA_POSITION_WORLD, normalize(world - CAMERA_POSITION_WORLD));
  POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(world, 1.0));
}

void fragment() {
  vec3 toward = world - CAMERA_POSITION_WORLD;
  float along = length(toward);
  vec3 view = toward / along;
  // The far side of the ring passes behind the body.
  float hit = zs_planet_hit(CAMERA_POSITION_WORLD, view);
  if (hit > 0.0 && hit < along) discard;
  float r = length(local.xz);
  // Dust lanes with one clear gap, fading at both edges. The lanes are
  // eased by the screen footprint of a radius step, so they never alias.
  float lanes = 0.6 + 0.4 * sin(r * 44.0) * (1.0 - smoothstep(0.02, 0.06, fwidth(r)));
  float gap = 1.0 - 0.85 * exp(-pow((r - 1.86) / 0.04, 2.0));
  float density = smoothstep(1.38, 1.5, r) * (1.0 - smoothstep(2.15, 2.3, r)) * lanes * gap;
  // The planet's shadow: does the way to the sun cross the body?
  vec3 centre = zs_planet_centre(CAMERA_POSITION_WORLD);
  vec3 oc = world - centre;
  float b = dot(oc, zs_sun_direction);
  float rr = zs_planet_world_radius();
  float shade = (b < 0.0 && dot(oc, oc) - b * b < rr * rr) ? 0.08 : 1.0;
  float lit = (0.25 + 0.75 * abs(dot(zs_planet_axes()[1], zs_sun_direction))) * shade;
  vec3 col = vec3(0.86, 0.79, 0.66) * (0.05 + 0.85 * lit);
  float presence = zs_planet_presence(view, zs_room_from_world(view)) * clouds;
  ALBEDO = scene_linear_for_display(col);
  ALPHA = density * 0.7 * presence * mix(lit * 0.3, 1.0, zs_night);
}
