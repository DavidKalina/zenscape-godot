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
  // The planet's shadow: does the way to the sun cross the body?
  vec3 centre = zs_planet_centre(CAMERA_POSITION_WORLD);
  vec3 oc = world - centre;
  float b = dot(oc, zs_sun_direction);
  float rr = zs_planet_world_radius();
  float shade = (b < 0.0 && dot(oc, oc) - b * b < rr * rr) ? 0.0 : 1.0;
  // Opal's shadow has a soft edge.
  if (zs_night_style == 1) shade = b < 0.0 ? smoothstep(rr * 0.9, rr * 1.12, sqrt(max(dot(oc, oc) - b * b, 0.0))) : 1.0;
  float lit = abs(dot(zs_planet_axes()[1], zs_sun_direction));
  // Its dust is the night style's (zs_night_planet_rings), eased by the
  // screen footprint of a radius step so its lanes never alias.
  vec4 dust = zs_night_planet_rings(local, fwidth(length(local.xz)), lit, shade);
  float day = (0.25 + 0.75 * lit) * mix(0.08, 1.0, shade);
  float presence = zs_planet_presence(view, zs_room_from_world(view)) * clouds;
  ALBEDO = scene_linear_for_display(clamp(dust.rgb, 0.0, 1.0));
  ALPHA = dust.a * presence * mix(day * 0.3, 1.0, zs_night);
}
